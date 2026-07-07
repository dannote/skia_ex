defmodule Skia.Codegen.Rusty.Paths do
  @moduledoc """
  Rusty Elixir path drawing implementation generation.
  """

  alias Skia.Codegen.Commands.Paths

  use Skia.Codegen.Rusty.Domain,
    from: Paths,
    commands: [:path, :path_op, :path_outline],
    rust_packages: [{"skia-safe", [manifest_path: "native/skia_native/Cargo.toml"]}]

  use Skia.Codegen.Rusty.Args

  alias RustQ.Type, as: R

  defrustmod(SkiaSafe.ArcSize, as: [:skia_safe, :path_builder, :ArcSize])
  defrustmod(SkiaSafe.Path, as: [:skia_safe, :Path])

  @spec decode_path_direction(atom()) :: R.nif_result(R.path(:PathDirection))
  defrust decode_path_direction(value) do
    case value do
      :cw -> {:ok, PathDirection.CW}
      :ccw -> {:ok, PathDirection.CCW}
      _ -> {:error, badarg()}
    end
  end

  @spec build_path(term()) :: R.nif_result(R.path({:skia_safe, :Path}))
  defrust build_path(path_term) do
    case decode_as(path_term, {atom(), R.path(:String)}) do
      {:ok, {tag, svg}} ->
        if tag == Atoms.svg() do
          {:ok, ok_or!(SkiaSafe.Path.from_svg(svg), badarg())}
        else
          build_path_from_compact_tuple(path_term)
        end

      {:error, _reason} ->
        build_path_from_compact_tuple(path_term)
    end
  end

  @spec build_path_from_compact_tuple(term()) :: R.nif_result(R.path({:skia_safe, :Path}))
  defrust build_path_from_compact_tuple(path_term) do
    case decode_as(path_term, {atom(), R.vec(term())}) do
      {:ok, {tag, segments}} ->
        if tag == Atoms.p() do
          build_compact_path(segments)
        else
          build_path_from_svg_field(path_term)
        end

      {:error, _reason} ->
        build_path_from_svg_field(path_term)
    end
  end

  @spec build_path_from_svg_field(term()) :: R.nif_result(R.path({:skia_safe, :Path}))
  defrust build_path_from_svg_field(path_term) do
    case path_term.map_get(Atoms.svg()) do
      {:ok, svg_term} ->
        case decode_as(svg_term, R.path(:String)) do
          {:ok, svg} -> {:ok, ok_or!(SkiaSafe.Path.from_svg(svg), badarg())}
          {:error, _reason} -> build_path_from_segments_field(path_term)
        end

      {:error, _reason} ->
        build_path_from_segments_field(path_term)
    end
  end

  @spec build_path_from_segments_field(term()) :: R.nif_result(R.path({:skia_safe, :Path}))
  defrust build_path_from_segments_field(path_term) do
    segments = decode_as!(unwrap!(path_term.map_get(Atoms.segments())), R.vec(term()))
    builder = PathBuilder.new()

    for segment <- segments.into_iter().rev() do
      case decode_as(segment, atom()) do
        {:ok, op} ->
          case op do
            :close -> builder.close()
            _ -> :ok
          end

        {:error, _reason} ->
          :ok
      end

      case decode_as(segment, {atom(), R.f64(), R.f64()}) do
        {:ok, {op, x, y}} ->
          point = {cast(x, :f32), cast(y, :f32)}

          case op do
            :move_to -> builder.move_to(point)
            :line_to -> builder.line_to(point)
            :r_move_to -> builder.r_move_to(point)
            :r_line_to -> builder.r_line_to(point)
            _ -> :ok
          end

        {:error, _reason} ->
          :ok
      end

      case decode_as(segment, {atom(), R.f64(), R.f64(), R.f64(), R.f64()}) do
        {:ok, {op, cx, cy, x, y}} ->
          control = {cast(cx, :f32), cast(cy, :f32)}
          point = {cast(x, :f32), cast(y, :f32)}

          case op do
            :quad_to -> builder.quad_to(control, point)
            :r_quad_to -> builder.r_quad_to(control, point)
            _ -> :ok
          end

        {:error, _reason} ->
          :ok
      end

      case decode_as(segment, {atom(), R.f64(), R.f64(), R.f64(), R.f64(), R.f64()}) do
        {:ok, {op, cx, cy, x, y, weight}} ->
          control = {cast(cx, :f32), cast(cy, :f32)}
          point = {cast(x, :f32), cast(y, :f32)}

          case op do
            :conic_to -> builder.conic_to(control, point, cast(weight, :f32))
            :r_conic_to -> builder.r_conic_to(control, point, cast(weight, :f32))
            _ -> :ok
          end

        {:error, _reason} ->
          :ok
      end

      case decode_as(segment, {atom(), R.f64(), R.f64(), R.f64(), R.f64(), R.f64(), term()}) do
        {:ok, {op, x, y, width, height, start, arc_opts}} ->
          if op == Atoms.arc_to() do
            {sweep, force_move_to} = decode_as!(arc_opts, {R.f64(), R.bool()})

            builder.arc_to(
              Rect.from_xywh(cast(x, :f32), cast(y, :f32), cast(width, :f32), cast(height, :f32)),
              cast(start, :f32),
              cast(sweep, :f32),
              force_move_to
            )
          end

        {:error, _reason} ->
          :ok
      end

      case decode_as(segment, {atom(), R.f64(), R.f64(), R.f64(), term()}) do
        {:ok, {op, rx, ry, x_axis_rotate, arc_opts}} ->
          if op == Atoms.r_arc_to() do
            {large_arc, sweep, dx, dy} =
              decode_as!(arc_opts, {R.bool(), atom(), R.f64(), R.f64()})

            arc_size =
              if large_arc do
                SkiaSafe.ArcSize.Large
              else
                SkiaSafe.ArcSize.Small
              end

            builder.r_arc_to(
              {cast(rx, :f32), cast(ry, :f32)},
              cast(x_axis_rotate, :f32),
              arc_size,
              unwrap!(decode_path_direction(sweep)),
              {cast(dx, :f32), cast(dy, :f32)}
            )
          end

        {:error, _reason} ->
          :ok
      end

      case decode_as(segment, {atom(), R.f64(), R.f64(), R.f64(), R.f64(), R.f64(), R.f64()}) do
        {:ok, {op, x, y, width, height, rx, ry}} ->
          if op == Atoms.rrect() do
            builder.add_rrect(
              RRect.new_rect_xy(
                Rect.from_xywh(
                  cast(x, :f32),
                  cast(y, :f32),
                  cast(width, :f32),
                  cast(height, :f32)
                ),
                cast(rx, :f32),
                cast(ry, :f32)
              ),
              none(),
              none()
            )
          end

        {:error, _reason} ->
          :ok
      end

      case decode_as(segment, {atom(), R.f64(), R.f64(), R.f64(), R.f64(), R.f64(), R.f64()}) do
        {:ok, {op, c1x, c1y, c2x, c2y, x, y}} ->
          control_1 = {cast(c1x, :f32), cast(c1y, :f32)}
          control_2 = {cast(c2x, :f32), cast(c2y, :f32)}
          point = {cast(x, :f32), cast(y, :f32)}

          case op do
            :cubic_to -> builder.cubic_to(control_1, control_2, point)
            :r_cubic_to -> builder.r_cubic_to(control_1, control_2, point)
            _ -> :ok
          end

        {:error, _reason} ->
          :ok
      end
    end

    {:ok, builder.detach()}
  end

  @spec build_compact_path(R.vec(term())) :: R.nif_result(R.path({:skia_safe, :Path}))
  defrust build_compact_path(segments) do
    builder = PathBuilder.new()

    for segment <- segments do
      case decode_as(segment, R.raw("(i64,)")) do
        {:ok, close} ->
          if tuple_field(close, 0) == 14 do
            builder.close()
          end

        {:error, _reason} ->
          :ok
      end

      case decode_as(segment, {R.i64(), R.f64(), R.f64()}) do
        {:ok, {op, x, y}} ->
          point = {cast(x, :f32), cast(y, :f32)}

          case op do
            1 -> builder.move_to(point)
            2 -> builder.line_to(point)
            6 -> builder.r_move_to(point)
            7 -> builder.r_line_to(point)
            _ -> :ok
          end

        {:error, _reason} ->
          :ok
      end

      case decode_as(segment, {R.i64(), R.f64(), R.f64(), R.f64(), R.f64()}) do
        {:ok, {op, cx, cy, x, y}} ->
          control = {cast(cx, :f32), cast(cy, :f32)}
          point = {cast(x, :f32), cast(y, :f32)}

          case op do
            3 -> builder.quad_to(control, point)
            8 -> builder.r_quad_to(control, point)
            _ -> :ok
          end

        {:error, _reason} ->
          :ok
      end

      case decode_as(segment, {R.i64(), R.f64(), R.f64(), R.f64(), R.f64(), R.f64()}) do
        {:ok, {op, cx, cy, x, y, weight}} ->
          control = {cast(cx, :f32), cast(cy, :f32)}
          point = {cast(x, :f32), cast(y, :f32)}

          case op do
            4 -> builder.conic_to(control, point, cast(weight, :f32))
            9 -> builder.r_conic_to(control, point, cast(weight, :f32))
            _ -> :ok
          end

        {:error, _reason} ->
          :ok
      end

      case decode_as(segment, {R.i64(), R.f64(), R.f64(), R.f64(), R.f64(), R.f64(), R.f64()}) do
        {:ok, {op, c1x, c1y, c2x, c2y, x, y}} ->
          control_1 = {cast(c1x, :f32), cast(c1y, :f32)}
          control_2 = {cast(c2x, :f32), cast(c2y, :f32)}
          point = {cast(x, :f32), cast(y, :f32)}

          case op do
            5 ->
              builder.cubic_to(control_1, control_2, point)

            10 ->
              builder.r_cubic_to(control_1, control_2, point)

            13 ->
              builder.add_rrect(
                RRect.new_rect_xy(
                  Rect.from_xywh(
                    cast(c1x, :f32),
                    cast(c1y, :f32),
                    cast(c2x, :f32),
                    cast(c2y, :f32)
                  ),
                  cast(x, :f32),
                  cast(y, :f32)
                ),
                none(),
                none()
              )

            _ ->
              :ok
          end

        {:error, _reason} ->
          :ok
      end

      case decode_as(segment, {R.i64(), R.f64(), R.f64(), R.f64(), R.f64(), R.f64(), term()}) do
        {:ok, {op, x, y, width, height, start, arc_opts}} ->
          if op == 11 do
            {sweep, force_move_to} = decode_as!(arc_opts, {R.f64(), R.bool()})

            builder.arc_to(
              Rect.from_xywh(cast(x, :f32), cast(y, :f32), cast(width, :f32), cast(height, :f32)),
              cast(start, :f32),
              cast(sweep, :f32),
              force_move_to
            )
          end

        {:error, _reason} ->
          :ok
      end

      case decode_as(segment, {R.i64(), R.f64(), R.f64(), R.f64(), term()}) do
        {:ok, {op, rx, ry, x_axis_rotate, arc_opts}} ->
          if op == 12 do
            {large_arc, sweep, dx, dy} =
              decode_as!(arc_opts, {R.bool(), atom(), R.f64(), R.f64()})

            arc_size =
              if large_arc do
                SkiaSafe.ArcSize.Large
              else
                SkiaSafe.ArcSize.Small
              end

            builder.r_arc_to(
              {cast(rx, :f32), cast(ry, :f32)},
              cast(x_axis_rotate, :f32),
              arc_size,
              unwrap!(decode_path_direction(sweep)),
              {cast(dx, :f32), cast(dy, :f32)}
            )
          end

        {:error, _reason} ->
          :ok
      end
    end

    {:ok, builder.detach()}
  end

  @spec draw_path_impl(
          R.ref(SkiaSafe.Canvas.t()),
          R.vec(term()),
          GeneratedOpts.PathOpts.t(R.lifetime(:a)),
          R.slice({atom(), term()})
        ) :: R.nif_result(R.unit())
  defrust draw_path_impl(canvas, args, opts, raw_opts) do
    path = build_path(first_arg_term!())
    apply_fill_rule(path, raw_opts)

    case opts.fill do
      {:some, fill} ->
        paint = decode_paint(fill)
        apply_blend_mode(paint, raw_opts)
        canvas.draw_path(path, paint)

      :none ->
        :ok
    end

    case opts.stroke do
      {:some, stroke} ->
        stroke_paint_value =
          unwrap!(
            stroke_paint(
              decode_color(stroke),
              opts.stroke_width.unwrap_or(1.0),
              raw_opts
            )
          )

        canvas.draw_path(path, stroke_paint_value)

      :none ->
        :ok
    end

    :ok
  end

  @spec draw_path_op_impl(
          R.ref(SkiaSafe.Canvas.t()),
          R.vec(term()),
          GeneratedOpts.PathOpOpts.t(R.lifetime(:a)),
          R.slice({atom(), term()})
        ) :: R.nif_result(R.unit())
  defrust draw_path_op_impl(canvas, args, opts, raw_opts) do
    a = build_path(first_arg_term!())
    b = build_path(arg_term!(1))
    op = unwrap!(GeneratedEnums.decode_path_op(opts.path_op))
    path = a.op(b, op).ok_or(badarg())
    apply_fill_rule(path, raw_opts)

    case opts.fill do
      {:some, fill} ->
        paint = decode_paint(fill)
        apply_blend_mode(paint, raw_opts)
        canvas.draw_path(path, paint)

      :none ->
        :ok
    end

    case opts.stroke do
      {:some, stroke} ->
        stroke_paint_value =
          unwrap!(
            stroke_paint(
              decode_color(stroke),
              opts.stroke_width.unwrap_or(1.0),
              raw_opts
            )
          )

        canvas.draw_path(path, stroke_paint_value)

      :none ->
        :ok
    end

    :ok
  end

  @spec draw_path_outline_impl(
          R.ref(SkiaSafe.Canvas.t()),
          R.vec(term()),
          GeneratedOpts.PathOutlineOpts.t(R.lifetime(:a)),
          R.slice({atom(), term()})
        ) :: R.nif_result(R.unit())
  defrust draw_path_outline_impl(canvas, args, opts, raw_opts) do
    path = build_path(first_arg_term!())
    stroke = Paint.default()
    stroke.set_anti_alias(true).set_style(PaintStyle.Stroke).set_stroke_width(opts.outline_width)
    apply_stroke_options(stroke, raw_opts)
    builder = PathBuilder.new()

    if PathUtils.fill_path_with_paint(path, stroke, builder, none(), none()) == false do
      :ok
    else
      outline = builder.detach()
      apply_fill_rule(outline, raw_opts)

      case opts.fill do
        {:some, fill} ->
          paint = decode_paint(fill)
          apply_blend_mode(paint, raw_opts)
          canvas.draw_path(outline, paint)

        :none ->
          case opts.stroke do
            {:some, stroke_color} ->
              paint = fill_paint(decode_color(stroke_color))
              apply_blend_mode(paint, raw_opts)
              canvas.draw_path(outline, paint)

            :none ->
              :ok
          end
      end

      :ok
    end
  end
end
