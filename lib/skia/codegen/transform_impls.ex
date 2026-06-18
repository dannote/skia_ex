defmodule Skia.Codegen.TransformImpls do
  @moduledoc """
  RustQ-backed transform implementation generation.

  Skia derives generated Rust signature types in `@spec`s while RustQ lowers
  valid Rusty Elixir bodies through `defrust`.
  """

  alias RustQ.Rust.AST
  alias Skia.CommandSpec.Transforms

  @commands [:translate, :scale, :rotate, :rotate_at, :concat]

  @spec commands() :: [atom()]
  def commands, do: @commands

  @spec generated_asts() :: [AST.Function.t()]
  def generated_asts do
    Transforms.commands()
    |> Keyword.take(@commands)
    |> Enum.map(fn {name, spec} -> generated_ast(name, spec) end)
  end

  defp generated_ast(_name, spec) do
    spec |> Keyword.fetch!(:handler) |> impl_ast!()
  end

  defp impl_ast!(handler) do
    name = String.to_atom("#{handler}_impl")

    Enum.find(__MODULE__.Rusty.__rustq_asts__(), &(&1.name == name)) ||
      raise "missing Rusty transform impl #{name}"
  end

  defmodule Rusty do
    @moduledoc false

    use RustQ.Meta

    alias RustQ.Type, as: R

    @spec draw_translate_impl(
            R.ref(SkiaSafe.Canvas.t()),
            GeneratedOpts.TranslateOpts.t(R.lifetime(:a)),
            R.slice({R.atom(), R.term()})
          ) :: R.nif_result(R.unit())
    defrust draw_translate_impl(canvas, opts, _raw_opts) do
      canvas.translate({opts.x, opts.y})
      :ok
    end

    @spec draw_scale_impl(
            R.ref(SkiaSafe.Canvas.t()),
            GeneratedOpts.ScaleOpts.t(R.lifetime(:a)),
            R.slice({R.atom(), R.term()})
          ) :: R.nif_result(R.unit())
    defrust draw_scale_impl(canvas, opts, _raw_opts) do
      canvas.scale({opts.x, opts.y})
      :ok
    end

    @spec draw_rotate_impl(
            R.ref(SkiaSafe.Canvas.t()),
            GeneratedOpts.RotateOpts.t(R.lifetime(:a)),
            R.slice({R.atom(), R.term()})
          ) :: R.nif_result(R.unit())
    defrust draw_rotate_impl(canvas, opts, _raw_opts) do
      canvas.rotate(opts.degrees, none())
      :ok
    end

    @spec draw_rotate_at_impl(
            R.ref(SkiaSafe.Canvas.t()),
            GeneratedOpts.RotateAtOpts.t(R.lifetime(:a)),
            R.slice({R.atom(), R.term()})
          ) :: R.nif_result(R.unit())
    defrust draw_rotate_at_impl(canvas, opts, _raw_opts) do
      canvas.rotate(opts.degrees, some(Point.new(opts.x, opts.y)))
      :ok
    end

    @spec draw_concat_impl(
            R.ref(SkiaSafe.Canvas.t()),
            GeneratedOpts.ConcatOpts.t(R.lifetime(:a)),
            R.slice({R.atom(), R.term()})
          ) :: R.nif_result(R.unit())
    defrust draw_concat_impl(canvas, opts, _raw_opts) do
      matrix = unwrap!(matrix_from_term(opts.matrix))
      canvas.concat(ref(matrix))
      :ok
    end
  end
end
