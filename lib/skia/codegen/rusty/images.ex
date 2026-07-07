defmodule Skia.Codegen.Rusty.Images do
  @moduledoc """
  Rusty Elixir image and picture drawing implementation generation.
  """

  alias Skia.Codegen.Commands.Images

  use Skia.Codegen.Rusty.Domain,
    from: Images,
    commands: [:image, :picture],
    helpers: [:draw_image_source_or_default],
    rust_packages: [{"skia-safe", [manifest_path: "native/skia_native/Cargo.toml"]}]

  use Skia.Codegen.Rusty.Args

  alias RustQ.Type, as: R

  @spec draw_image_impl(
          R.ref(SkiaSafe.Canvas.t()),
          R.vec(term()),
          GeneratedOpts.ImageOpts.t(R.lifetime(:a)),
          R.slice({atom(), term()})
        ) :: R.nif_result(R.unit())
  defrust draw_image_impl(canvas, args, opts, raw_opts) do
    image = image_from_term(first_arg_term!())
    paint = Paint.default()
    paint.set_anti_alias(true)

    case opts.opacity do
      {:some, opacity} ->
        alpha = opacity |> clamp(0.0, 1.0) |> Kernel.*(255.0) |> round() |> cast(:u8)
        paint.set_alpha(alpha)

      :none ->
        :ok
    end

    apply_blend_mode(paint, raw_opts)
    sampling = opt_sampling(raw_opts, Atoms.sampling())

    source =
      case opts.source do
        {:some, term} -> some(rect_from_term(term))
        :none -> none()
      end

    case opts.width do
      {:some, width} ->
        case opts.height do
          {:some, height} ->
            src = source.as_ref().map(fn rect -> {rect, SrcRectConstraint.Strict} end)

            canvas.draw_image_rect_with_sampling_options(
              image,
              src,
              Rect.from_xywh(opts.x, opts.y, width, height),
              sampling,
              paint
            )

          :none ->
            draw_image_source_or_default(canvas, image, source, opts, sampling, paint)
        end

      :none ->
        draw_image_source_or_default(canvas, image, source, opts, sampling, paint)
    end

    :ok
  end

  @spec draw_image_source_or_default(
          R.ref(SkiaSafe.Canvas.t()),
          Image.t(),
          R.option(Rect.t()),
          GeneratedOpts.ImageOpts.t(R.lifetime(:a)),
          SamplingOptions.t(),
          R.ref(Paint.t())
        ) :: R.unit()
  defrust draw_image_source_or_default(canvas, image, source, opts, sampling, paint) do
    case source do
      {:some, source} ->
        canvas.draw_image_rect_with_sampling_options(
          image,
          some({source, SrcRectConstraint.Strict}),
          Rect.from_xywh(opts.x, opts.y, source.width(), source.height()),
          sampling,
          paint
        )

      :none ->
        canvas.draw_image_with_sampling_options(image, {opts.x, opts.y}, sampling, some(paint))
    end

    :ok
  end

  @spec draw_picture_impl(
          R.ref(SkiaSafe.Canvas.t()),
          R.vec(term()),
          GeneratedOpts.PictureOpts.t(R.lifetime(:a)),
          R.slice({atom(), term()})
        ) :: R.nif_result(R.unit())
  defrust draw_picture_impl(canvas, args, opts, raw_opts) do
    picture = picture_from_term(first_arg_term!())
    paint = Paint.default()
    paint.set_anti_alias(true)

    case opts.opacity do
      {:some, opacity} ->
        alpha = opacity |> clamp(0.0, 1.0) |> Kernel.*(255.0) |> round() |> cast(:u8)
        paint.set_alpha(alpha)

      :none ->
        :ok
    end

    apply_blend_mode(paint, raw_opts)
    canvas.save()
    canvas.translate({opts.x.unwrap_or(0.0), opts.y.unwrap_or(0.0)})
    canvas.draw_picture(picture, none(), some(paint))
    canvas.restore()

    :ok
  end
end
