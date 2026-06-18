defmodule Skia.Codegen.Rusty.Clips do
  @moduledoc """
  Rusty Elixir clip implementation generation.
  """

  alias RustQ.Rust.AST
  alias Skia.CommandSpec.Clips

  @commands [:clip_rect, :clip_circle, :clip_path]

  @spec commands() :: [atom()]
  def commands, do: @commands

  @spec generated_asts() :: [AST.Function.t()]
  def generated_asts do
    Clips.commands()
    |> Keyword.take(@commands)
    |> Enum.map(fn {_name, spec} -> spec |> Keyword.fetch!(:handler) |> impl_ast!() end)
  end

  defp impl_ast!(handler) do
    name = String.to_atom("#{handler}_impl")

    Enum.find(__rustq_asts__(), &(&1.name == name)) ||
      raise "missing Rusty clip impl #{name}"
  end

  use RustQ.Meta

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
    path = unwrap!(build_path(deref(unwrap!(args.first().ok_or(badarg())))))
    unwrap!(apply_fill_rule(mut_ref(path), raw_opts))
    clip_op = unwrap!(decode_clip_op(opts.clip_op.unwrap_or(Atoms.intersect())))
    canvas.clip_path(ref(path), clip_op, opts.antialias.unwrap_or(true))

    :ok
  end
end
