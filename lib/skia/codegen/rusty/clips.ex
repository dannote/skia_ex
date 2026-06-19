defmodule Skia.Codegen.Rusty.Clips do
  @moduledoc """
  Rusty Elixir clip implementation generation.
  """

  alias Skia.Codegen.Commands.Clips

  use Skia.Codegen.Rusty.Domain,
    from: Clips,
    commands: [:clip_rect, :clip_circle, :clip_path]

  use Skia.Codegen.Rusty.Args

  alias RustQ.Type, as: R

  @spec clip_rect_impl(
          R.ref(SkiaSafe.Canvas.t()),
          GeneratedOpts.ClipRectOpts.t(R.lifetime(:a)),
          R.slice({R.atom(), R.term()})
        ) :: R.nif_result(R.unit())
  defrust clip_rect_impl(canvas, opts, _raw_opts) do
    rect = Rect.from_xywh(opts.x, opts.y, opts.width, opts.height)
    radius = opts.radius.unwrap_or(0.0)
    antialias = opts.antialias.unwrap_or(true)
    clip_op = unwrap!(decode_clip_op(opts.clip_op.unwrap_or(Atoms.intersect())))

    if radius > 0.0 do
      canvas.clip_rrect(RRect.new_rect_xy(rect, radius, radius), clip_op, antialias)
    else
      canvas.clip_rect(rect, clip_op, antialias)
    end

    :ok
  end

  @spec clip_circle_impl(
          R.ref(SkiaSafe.Canvas.t()),
          GeneratedOpts.ClipCircleOpts.t(R.lifetime(:a)),
          R.slice({R.atom(), R.term()})
        ) :: R.nif_result(R.unit())
  defrust clip_circle_impl(canvas, opts, _raw_opts) do
    builder = PathBuilder.new()
    builder.add_circle(Point.new(opts.x, opts.y), opts.radius, none())
    path = builder.detach()
    clip_op = unwrap!(decode_clip_op(opts.clip_op.unwrap_or(Atoms.intersect())))
    canvas.clip_path(ref(path), clip_op, opts.antialias.unwrap_or(true))

    :ok
  end

  @spec clip_path_impl(
          R.ref(SkiaSafe.Canvas.t()),
          R.vec(R.term()),
          GeneratedOpts.ClipPathOpts.t(R.lifetime(:a)),
          R.slice({R.atom(), R.term()})
        ) :: R.nif_result(R.unit())
  defrust clip_path_impl(canvas, args, opts, raw_opts) do
    path = unwrap!(build_path(first_arg_term!()))
    unwrap!(apply_fill_rule(mut_ref(path), raw_opts))
    clip_op = unwrap!(decode_clip_op(opts.clip_op.unwrap_or(Atoms.intersect())))
    canvas.clip_path(ref(path), clip_op, opts.antialias.unwrap_or(true))

    :ok
  end
end
