defmodule Skia.Codegen.Rusty.Shapes do
  @moduledoc """
  Rusty Elixir shape implementation generation.

  Skia owns drawing semantics and generated Rust signatures; RustQ owns lowering
  valid Elixir `@spec + defrust` bodies to Rust.
  """

  alias Skia.Codegen.Commands.Shapes

  use Skia.Codegen.Rusty.Domain,
    from: Shapes,
    commands: [:clear, :rect, :circle, :oval, :arc, :vertices, :line],
    helpers: [:draw_rect_shape]

  use Skia.Codegen.Rusty.Paint

  alias RustQ.Type, as: R

  @spec draw_clear_impl(R.ref(SkiaSafe.Canvas.t()), R.vec(R.term())) :: R.nif_result(R.unit())
  defrust draw_clear_impl(canvas, args) do
    case args.first().and_then(fn term -> decode_color(deref(term)).ok() end) do
      {:some, color} -> canvas.clear(color)
      :none -> :ok
    end

    :ok
  end

  @spec draw_rect_impl(
          R.ref(SkiaSafe.Canvas.t()),
          GeneratedOpts.RectOpts.t(R.lifetime(:a)),
          R.slice({R.atom(), R.term()})
        ) :: R.nif_result(R.unit())
  defrust draw_rect_impl(canvas, opts, raw_opts) do
    rect = Rect.from_xywh(opts.x, opts.y, opts.width, opts.height)
    radius = opts.radius.unwrap_or(0.0)

    with_fill_paint do
      draw_rect_shape(canvas, rect, radius, ref(paint))
    end

    with_stroke_paint opts.stroke_width.unwrap_or(1.0) do
      draw_rect_shape(canvas, rect, radius, ref(stroke_paint_value))
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

  @spec draw_arc_impl(
          R.ref(SkiaSafe.Canvas.t()),
          GeneratedOpts.ArcOpts.t(R.lifetime(:a)),
          R.slice({R.atom(), R.term()})
        ) :: R.nif_result(R.unit())
  defrust draw_arc_impl(canvas, opts, raw_opts) do
    rect = Rect.from_xywh(opts.x, opts.y, opts.width, opts.height)
    use_center = opts.use_center.unwrap_or(false)

    with_fill_paint do
      canvas.draw_arc(rect, opts.start_degrees, opts.sweep_degrees, use_center, ref(paint))
    end

    with_stroke_paint opts.stroke_width.unwrap_or(1.0) do
      canvas.draw_arc(
        rect,
        opts.start_degrees,
        opts.sweep_degrees,
        use_center,
        ref(stroke_paint_value)
      )
    end

    :ok
  end

  @spec draw_vertices_impl(
          R.ref(SkiaSafe.Canvas.t()),
          R.vec(R.term()),
          GeneratedOpts.VerticesOpts.t(R.lifetime(:a)),
          R.slice({R.atom(), R.term()})
        ) :: R.nif_result(R.unit())
  defrust draw_vertices_impl(canvas, args, opts, raw_opts) do
    vertices = unwrap!(vertices_from_term(deref(unwrap!(args.first().ok_or(badarg())))))

    blend_mode =
      unwrap!(GeneratedEnums.decode_blend_mode(opts.blend_mode.unwrap_or(Atoms.src_over())))

    paint =
      case opts.fill do
        {:some, term} -> unwrap!(decode_paint(term))
        :none -> fill_paint(Color.WHITE)
      end

    unwrap!(apply_paint_effects(mut_ref(paint), raw_opts))
    canvas.draw_vertices(ref(vertices), blend_mode, ref(paint))

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

  @spec draw_rect_shape(R.ref(SkiaSafe.Canvas.t()), Rect.t(), R.f32(), R.ref(Paint.t())) ::
          R.unit()
  defrust draw_rect_shape(canvas, rect, radius, paint) do
    if radius > 0.0 do
      canvas.draw_rrect(RRect.new_rect_xy(rect, radius, radius), paint)
    else
      canvas.draw_rect(rect, paint)
    end

    :ok
  end
end
