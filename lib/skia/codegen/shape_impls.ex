defmodule Skia.Codegen.ShapeImpls do
  @moduledoc """
  RustQ-backed shape implementation generation.

  This module is the shape-family equivalent of `Skia.Codegen.TransformImpls`:
  Skia derives the generated Rust signature types, while RustQ lowers valid
  Elixir bodies through `defrust`; Skia derives the generated Rust signature
  types in `@spec`s while RustQ lowers valid Rusty Elixir bodies.
  """

  alias RustQ.Rust.AST
  alias RustQ.Rust.AST.TypeBuilder, as: T
  alias Skia.Codegen.ImplHelpers
  alias Skia.CommandSpec.Shapes

  @commands [:clear, :circle, :oval, :line]

  @spec commands() :: [atom()]
  def commands, do: @commands

  @spec generated_asts() :: [AST.Function.t()]
  def generated_asts do
    Shapes.commands()
    |> Keyword.take(@commands)
    |> Enum.map(fn {name, spec} -> generated_ast(name, spec) end)
  end

  defp generated_ast(:clear, spec) do
    spec |> Keyword.fetch!(:handler) |> impl_ast!()
  end

  defp generated_ast(:circle, spec) do
    handler = Keyword.fetch!(spec, :handler)

    RustQ.Meta.quoted(String.to_atom("#{handler}_impl"),
      args: ImplHelpers.command_impl_args(:circle, :raw_opts),
      returns: T.nif_result(T.unit()),
      rust_modules: %{[:Atoms] => [:atoms]},
      do: circle_body_quote!()
    )
  end

  defp generated_ast(:oval, spec) do
    handler = Keyword.fetch!(spec, :handler)

    RustQ.Meta.quoted(String.to_atom("#{handler}_impl"),
      args: ImplHelpers.command_impl_args(:oval, :raw_opts),
      returns: T.nif_result(T.unit()),
      rust_modules: %{[:Atoms] => [:atoms]},
      do: oval_body_quote!()
    )
  end

  defp generated_ast(_name, spec) do
    spec |> Keyword.fetch!(:handler) |> impl_ast!()
  end

  defp impl_ast!(handler) do
    name = String.to_atom("#{handler}_impl")

    Enum.find(__MODULE__.Rusty.__rustq_asts__(), &(&1.name == name)) ||
      raise "missing Rusty shape impl #{name}"
  end

  defp circle_body_quote! do
    quote do
      center = Point.new(opts.x, opts.y)

      case unwrap!(opt_fill_paint(raw_opts, Atoms.fill())) do
        {:some, paint} ->
          paint = paint
          unwrap!(apply_blend_mode(mut_ref(paint), raw_opts))
          canvas.draw_circle(center, opts.radius, ref(paint))

        :none ->
          :ok
      end

      case unwrap!(opt_color(raw_opts, Atoms.stroke())) do
        {:some, color} ->
          stroke_paint_value =
            unwrap!(stroke_paint(color, opts.stroke_width.unwrap_or(1.0), raw_opts))

          canvas.draw_circle(center, opts.radius, ref(stroke_paint_value))

        :none ->
          :ok
      end

      :ok
    end
  end

  defp oval_body_quote! do
    quote do
      rect = Rect.from_xywh(opts.x, opts.y, opts.width, opts.height)

      case unwrap!(opt_fill_paint(raw_opts, Atoms.fill())) do
        {:some, paint} ->
          paint = paint
          unwrap!(apply_blend_mode(mut_ref(paint), raw_opts))
          canvas.draw_oval(rect, ref(paint))

        :none ->
          :ok
      end

      case unwrap!(opt_color(raw_opts, Atoms.stroke())) do
        {:some, color} ->
          stroke_paint_value =
            unwrap!(stroke_paint(color, opts.stroke_width.unwrap_or(1.0), raw_opts))

          canvas.draw_oval(rect, ref(stroke_paint_value))

        :none ->
          :ok
      end

      :ok
    end
  end

  defmodule Rusty do
    @moduledoc false

    use RustQ.Meta

    alias RustQ.Type, as: R

    @spec draw_clear_impl(R.ref(R.path({:skia_safe, :Canvas})), R.vec(R.term())) ::
            R.nif_result(R.unit())
    defrust draw_clear_impl(canvas, args) do
      case args.first().and_then(fn term -> decode_color(deref(term)).ok() end) do
        {:some, color} -> canvas.clear(color)
        :none -> :ok
      end

      :ok
    end

    @spec draw_line_impl(
            R.ref(R.path({:skia_safe, :Canvas})),
            R.path({:generated_opts, :LineOpts}, R.lifetime(:a)),
            R.slice({R.atom(), R.term()})
          ) :: R.nif_result(R.unit())
    defrust draw_line_impl(canvas, opts, raw_opts) do
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
