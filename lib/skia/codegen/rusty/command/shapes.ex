defmodule Skia.Codegen.Rusty.Command.Shapes do
  @moduledoc """
  Rusty Elixir shape implementation generation.

  Skia owns drawing semantics and generated Rust signatures; RustQ owns lowering
  valid Elixir `@spec + defrust` bodies to Rust.
  """

  alias Skia.Codegen.Command.Domain.Shapes
  alias RustQ.Type, as: R

  use Skia.Codegen.Rusty.CommandDomain,
    from: Shapes,
    commands: [:clear, :rect, :circle, :oval, :arc, :vertices, :line],
    helpers: [:draw_rect_shape],
    rust_packages: [{"skia-safe", [manifest_path: "native/skia_native/Cargo.toml"]}]

  use Skia.Codegen.Rusty.Support.PaintMacros

  @spec draw_clear_impl(R.ref(SkiaSafe.Canvas.t()), R.vec(term())) :: R.nif_result(R.unit())
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
          R.slice({atom(), term()})
        ) :: R.nif_result(R.unit())
  defrust draw_rect_impl(canvas, opts, raw_opts) do
    rect = Rect.from_xywh(opts.x, opts.y, opts.width, opts.height)
    radius = opts.radius.unwrap_or(0.0)

    with_fill_paint do
      draw_rect_shape(canvas, rect, radius, paint)
    end

    with_stroke_paint opts.stroke_width.unwrap_or(1.0) do
      draw_rect_shape(canvas, rect, radius, stroke_paint_value)
    end

    :ok
  end

  @spec draw_circle_impl(
          R.ref(SkiaSafe.Canvas.t()),
          GeneratedOpts.CircleOpts.t(R.lifetime(:a)),
          R.slice({atom(), term()})
        ) :: R.nif_result(R.unit())
  defrust draw_circle_impl(canvas, opts, raw_opts) do
    center = Point.new(opts.x, opts.y)

    with_fill_paint do
      canvas.draw_circle(center, opts.radius, paint)
    end

    with_stroke_paint opts.stroke_width.unwrap_or(1.0) do
      canvas.draw_circle(center, opts.radius, stroke_paint_value)
    end

    :ok
  end

  @spec draw_oval_impl(
          R.ref(SkiaSafe.Canvas.t()),
          GeneratedOpts.OvalOpts.t(R.lifetime(:a)),
          R.slice({atom(), term()})
        ) :: R.nif_result(R.unit())
  defrust draw_oval_impl(canvas, opts, raw_opts) do
    rect = Rect.from_xywh(opts.x, opts.y, opts.width, opts.height)

    with_fill_paint do
      canvas.draw_oval(rect, paint)
    end

    with_stroke_paint opts.stroke_width.unwrap_or(1.0) do
      canvas.draw_oval(rect, stroke_paint_value)
    end

    :ok
  end

  @spec draw_arc_impl(
          R.ref(SkiaSafe.Canvas.t()),
          GeneratedOpts.ArcOpts.t(R.lifetime(:a)),
          R.slice({atom(), term()})
        ) :: R.nif_result(R.unit())
  defrust draw_arc_impl(canvas, opts, raw_opts) do
    rect = Rect.from_xywh(opts.x, opts.y, opts.width, opts.height)
    use_center = opts.use_center.unwrap_or(false)

    with_fill_paint do
      canvas.draw_arc(rect, opts.start_degrees, opts.sweep_degrees, use_center, paint)
    end

    with_stroke_paint opts.stroke_width.unwrap_or(1.0) do
      canvas.draw_arc(
        rect,
        opts.start_degrees,
        opts.sweep_degrees,
        use_center,
        stroke_paint_value
      )
    end

    :ok
  end

  @spec draw_vertices_impl(
          R.ref(SkiaSafe.Canvas.t()),
          R.vec(term()),
          GeneratedOpts.VerticesOpts.t(R.lifetime(:a)),
          R.slice({atom(), term()})
        ) :: R.nif_result(R.unit())
  defrust draw_vertices_impl(canvas, args, opts, raw_opts) do
    vertices = vertices_from_term(deref(unwrap!(args.first().ok_or(badarg()))))

    blend_mode =
      unwrap!(GeneratedEnums.decode_blend_mode(opts.blend_mode.unwrap_or(Atoms.src_over())))

    paint =
      case opts.fill do
        {:some, term} -> decode_paint(term)
        :none -> fill_paint(Color.WHITE)
      end

    apply_paint_effects(paint, raw_opts)
    canvas.draw_vertices(vertices, blend_mode, paint)

    :ok
  end

  @spec draw_line_impl(
          R.ref(SkiaSafe.Canvas.t()),
          GeneratedOpts.LineOpts.t(R.lifetime(:a)),
          R.slice({atom(), term()})
        ) :: R.nif_result(R.unit())
  defrust draw_line_impl(canvas, opts, raw_opts) do
    color = decode_color(opts.stroke)

    paint = stroke_paint(color, opts.stroke_width.unwrap_or(1.0), raw_opts)

    canvas.draw_line(
      point_from_term(opts.from),
      point_from_term(opts.to),
      paint
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
