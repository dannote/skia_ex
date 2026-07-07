defmodule Skia.Codegen.Rusty.Transforms do
  @moduledoc """
  Rusty Elixir transform implementation generation.

  Skia owns drawing semantics and generated Rust signatures; RustQ owns lowering
  valid Elixir `@spec + defrust` bodies to Rust.
  """

  alias Skia.Codegen.Commands.Transforms

  use Skia.Codegen.Rusty.Domain,
    from: Transforms,
    commands: [:translate, :scale, :rotate, :rotate_at, :concat],
    rust_packages: [{"skia-safe", [manifest_path: "native/skia_native/Cargo.toml"]}]

  alias RustQ.Type, as: R

  @spec draw_translate_impl(
          R.ref(SkiaSafe.Canvas.t()),
          GeneratedOpts.TranslateOpts.t(R.lifetime(:a)),
          R.slice({atom(), term()})
        ) :: R.nif_result(R.unit())
  defrust draw_translate_impl(canvas, opts, _raw_opts) do
    canvas.translate({opts.x, opts.y})
    :ok
  end

  @spec draw_scale_impl(
          R.ref(SkiaSafe.Canvas.t()),
          GeneratedOpts.ScaleOpts.t(R.lifetime(:a)),
          R.slice({atom(), term()})
        ) :: R.nif_result(R.unit())
  defrust draw_scale_impl(canvas, opts, _raw_opts) do
    canvas.scale({opts.x, opts.y})
    :ok
  end

  @spec draw_rotate_impl(
          R.ref(SkiaSafe.Canvas.t()),
          GeneratedOpts.RotateOpts.t(R.lifetime(:a)),
          R.slice({atom(), term()})
        ) :: R.nif_result(R.unit())
  defrust draw_rotate_impl(canvas, opts, _raw_opts) do
    canvas.rotate(opts.degrees, none())
    :ok
  end

  @spec draw_rotate_at_impl(
          R.ref(SkiaSafe.Canvas.t()),
          GeneratedOpts.RotateAtOpts.t(R.lifetime(:a)),
          R.slice({atom(), term()})
        ) :: R.nif_result(R.unit())
  defrust draw_rotate_at_impl(canvas, opts, _raw_opts) do
    canvas.rotate(opts.degrees, some(Point.new(opts.x, opts.y)))
    :ok
  end

  @spec draw_concat_impl(
          R.ref(SkiaSafe.Canvas.t()),
          GeneratedOpts.ConcatOpts.t(R.lifetime(:a)),
          R.slice({atom(), term()})
        ) :: R.nif_result(R.unit())
  defrust draw_concat_impl(canvas, opts, _raw_opts) do
    matrix = matrix_from_term(opts.matrix)
    canvas.concat(matrix)
    :ok
  end
end
