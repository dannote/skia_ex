defmodule Skia.Codegen.ShapeImpls do
  @moduledoc """
  RustQ-backed shape implementation generation.

  This module is the shape-family equivalent of `Skia.Codegen.TransformImpls`:
  Skia derives the generated Rust signature types, while RustQ lowers valid
  Elixir bodies through `RustQ.Meta.quoted/2`.
  """

  alias RustQ.Rust.AST
  alias RustQ.Rust.AST.Builder, as: A
  alias Skia.Codegen.ImplHelpers
  alias Skia.CommandSpec.Shapes

  @commands [:line]

  @spec commands() :: [atom()]
  def commands, do: @commands

  @spec generated_asts() :: [AST.Function.t()]
  def generated_asts do
    Shapes.commands()
    |> Keyword.take(@commands)
    |> Enum.map(fn {name, spec} -> generated_ast(name, spec) end)
  end

  defp generated_ast(name, spec) do
    handler = Keyword.fetch!(spec, :handler)

    RustQ.Meta.quoted(String.to_atom("#{handler}_impl"),
      args: ImplHelpers.command_impl_args(name, :raw_opts),
      returns: A.nif_result_type(A.unit_type()),
      do: line_body_ast!()
    )
  end

  defp line_body_ast! do
    quote do
      color = unwrap!(decode_color(opts.stroke))

      paint =
        unwrap!(stroke_paint(color, opts.stroke_width.unwrap_or(1.0), raw_opts))

      canvas.draw_line(
        unwrap!(point_from_term(opts.from)),
        unwrap!(point_from_term(opts.to)),
        ref(paint)
      )

      :ok
    end
  end
end
