defmodule Skia.Codegen.Rusty.Paths do
  @moduledoc """
  Rusty Elixir path drawing implementation generation.
  """

  alias Skia.Codegen.Commands.Paths

  use RustQ.Meta
  use Skia.Codegen.Rusty.Command
  use Skia.Codegen.Rusty.Args

  alias RustQ.Type, as: R

  defrust_commands(Paths, [:path, :path_op, :path_outline])

  @spec draw_path_impl(
          R.ref(SkiaSafe.Canvas.t()),
          R.vec(R.term()),
          GeneratedOpts.PathOpts.t(R.lifetime(:a)),
          R.slice({R.atom(), R.term()})
        ) :: R.nif_result(R.unit())
  defrust draw_path_impl(canvas, args, opts, raw_opts) do
    path = unwrap!(build_path(first_arg_term!()))
    unwrap!(apply_fill_rule(mut_ref(path), raw_opts))

    case opts.fill do
      {:some, fill} ->
        paint = unwrap!(decode_paint(fill))
        unwrap!(apply_blend_mode(mut_ref(paint), raw_opts))
        canvas.draw_path(ref(path), ref(paint))

      :none ->
        :ok
    end

    case opts.stroke do
      {:some, stroke} ->
        stroke_paint_value =
          unwrap!(
            stroke_paint(
              unwrap!(decode_color(stroke)),
              opts.stroke_width.unwrap_or(1.0),
              raw_opts
            )
          )

        canvas.draw_path(ref(path), ref(stroke_paint_value))

      :none ->
        :ok
    end

    :ok
  end

  @spec draw_path_op_impl(
          R.ref(SkiaSafe.Canvas.t()),
          R.vec(R.term()),
          GeneratedOpts.PathOpOpts.t(R.lifetime(:a)),
          R.slice({R.atom(), R.term()})
        ) :: R.nif_result(R.unit())
  defrust draw_path_op_impl(canvas, args, opts, raw_opts) do
    a = unwrap!(build_path(first_arg_term!()))
    b = unwrap!(build_path(arg_term!(1)))
    op = unwrap!(GeneratedEnums.decode_path_op(opts.path_op))
    path = unwrap!(a.op(ref(b), op).ok_or(badarg()))
    unwrap!(apply_fill_rule(mut_ref(path), raw_opts))

    case opts.fill do
      {:some, fill} ->
        paint = unwrap!(decode_paint(fill))
        unwrap!(apply_blend_mode(mut_ref(paint), raw_opts))
        canvas.draw_path(ref(path), ref(paint))

      :none ->
        :ok
    end

    case opts.stroke do
      {:some, stroke} ->
        stroke_paint_value =
          unwrap!(
            stroke_paint(
              unwrap!(decode_color(stroke)),
              opts.stroke_width.unwrap_or(1.0),
              raw_opts
            )
          )

        canvas.draw_path(ref(path), ref(stroke_paint_value))

      :none ->
        :ok
    end

    :ok
  end

  @spec draw_path_outline_impl(
          R.ref(SkiaSafe.Canvas.t()),
          R.vec(R.term()),
          GeneratedOpts.PathOutlineOpts.t(R.lifetime(:a)),
          R.slice({R.atom(), R.term()})
        ) :: R.nif_result(R.unit())
  defrust draw_path_outline_impl(canvas, args, opts, raw_opts) do
    path = unwrap!(build_path(first_arg_term!()))
    stroke = Paint.default()
    stroke.set_anti_alias(true).set_style(PaintStyle.Stroke).set_stroke_width(opts.outline_width)
    unwrap!(apply_stroke_options(mut_ref(stroke), raw_opts))
    builder = PathBuilder.new()

    if PathUtils.fill_path_with_paint(ref(path), ref(stroke), mut_ref(builder), none(), none()) ==
         false do
      return!(:ok)
    end

    outline = builder.detach()
    unwrap!(apply_fill_rule(mut_ref(outline), raw_opts))

    case opts.fill do
      {:some, fill} ->
        paint = unwrap!(decode_paint(fill))
        unwrap!(apply_blend_mode(mut_ref(paint), raw_opts))
        canvas.draw_path(ref(outline), ref(paint))

      :none ->
        case opts.stroke do
          {:some, stroke_color} ->
            paint = fill_paint(unwrap!(decode_color(stroke_color)))
            unwrap!(apply_blend_mode(mut_ref(paint), raw_opts))
            canvas.draw_path(ref(outline), ref(paint))

          :none ->
            :ok
        end
    end

    :ok
  end
end
