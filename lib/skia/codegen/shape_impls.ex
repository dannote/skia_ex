defmodule Skia.Codegen.ShapeImpls do
  @moduledoc """
  RustQ-backed shape implementation generation.

  This module is the shape-family equivalent of `Skia.Codegen.TransformImpls`:
  Skia derives the generated Rust signature types in `@spec`s while RustQ lowers
  valid Rusty Elixir bodies through `defrust`.
  """

  alias RustQ.Rust.AST
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

  defp generated_ast(_name, spec) do
    spec |> Keyword.fetch!(:handler) |> impl_ast!()
  end

  defp impl_ast!(handler) do
    name = String.to_atom("#{handler}_impl")

    Enum.find(__MODULE__.Rusty.__rustq_asts__(), &(&1.name == name)) ||
      raise "missing Rusty shape impl #{name}"
  end

  defmodule Rusty do
    @moduledoc false

    use RustQ.Meta

    alias RustQ.Type, as: R

    defmacro with_fill_paint(do: body) do
      quote do
        case unwrap!(opt_fill_paint(var!(raw_opts), Atoms.fill())) do
          {:some, var!(paint)} ->
            var!(paint) = var!(paint)
            unwrap!(apply_blend_mode(mut_ref(var!(paint)), var!(raw_opts)))
            unquote(body)

          :none ->
            :ok
        end
      end
    end

    defmacro with_stroke_paint(width, do: body) do
      quote do
        case unwrap!(opt_color(var!(raw_opts), Atoms.stroke())) do
          {:some, var!(color)} ->
            var!(stroke_paint_value) =
              unwrap!(stroke_paint(var!(color), unquote(width), var!(raw_opts)))

            unquote(body)

          :none ->
            :ok
        end
      end
    end

    @spec draw_clear_impl(R.ref(SkiaSafe.Canvas.t()), R.vec(R.term())) :: R.nif_result(R.unit())
    defrust draw_clear_impl(canvas, args) do
      case args.first().and_then(fn term -> decode_color(deref(term)).ok() end) do
        {:some, color} -> canvas.clear(color)
        :none -> :ok
      end

      :ok
    end

    @spec draw_circle_impl(
            R.ref(SkiaSafe.Canvas.t()),
            GeneratedOpts.CircleOpts.t(R.lifetime(:a)),
            R.slice({R.atom(), R.term()})
          ) :: R.nif_result(R.unit())
    defrust draw_circle_impl(canvas, opts, raw_opts) do
      center = Point.new(opts.x, opts.y)

      with_fill_paint do
        canvas.draw_circle(center, opts.radius, ref(paint))
      end

      with_stroke_paint opts.stroke_width.unwrap_or(1.0) do
        canvas.draw_circle(center, opts.radius, ref(stroke_paint_value))
      end

      :ok
    end

    @spec draw_oval_impl(
            R.ref(SkiaSafe.Canvas.t()),
            GeneratedOpts.OvalOpts.t(R.lifetime(:a)),
            R.slice({R.atom(), R.term()})
          ) :: R.nif_result(R.unit())
    defrust draw_oval_impl(canvas, opts, raw_opts) do
      rect = Rect.from_xywh(opts.x, opts.y, opts.width, opts.height)

      with_fill_paint do
        canvas.draw_oval(rect, ref(paint))
      end

      with_stroke_paint opts.stroke_width.unwrap_or(1.0) do
        canvas.draw_oval(rect, ref(stroke_paint_value))
      end

      :ok
    end

    @spec draw_line_impl(
            R.ref(SkiaSafe.Canvas.t()),
            GeneratedOpts.LineOpts.t(R.lifetime(:a)),
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
