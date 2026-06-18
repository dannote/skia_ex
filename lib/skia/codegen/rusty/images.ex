defmodule Skia.Codegen.Rusty.Images do
  @moduledoc """
  Rusty Elixir image and picture drawing implementation generation.
  """

  alias RustQ.Rust.AST
  alias Skia.CommandSpec.Images

  @commands [:image, :picture]

  @spec commands() :: [atom()]
  def commands, do: @commands

  @spec generated_asts() :: [AST.Function.t()]
  def generated_asts do
    command_asts =
      Images.commands()
      |> Keyword.take(@commands)
      |> Enum.map(fn {_name, spec} -> spec |> Keyword.fetch!(:handler) |> impl_ast!() end)

    command_asts ++ [rust_ast!(:draw_image_source_or_default)]
  end

  defp impl_ast!(handler) do
    name = String.to_atom("#{handler}_impl")

    rust_ast!(name)
  end

  defp rust_ast!(name) do
    Enum.find(__rustq_asts__(), &(&1.name == name)) ||
      raise "missing Rusty image impl #{name}"
  end

  use RustQ.Meta
  use Skia.Codegen.Rusty.Args

  alias RustQ.Type, as: R

  @spec draw_image_impl(
          R.ref(SkiaSafe.Canvas.t()),
          R.vec(R.term()),
          GeneratedOpts.ImageOpts.t(R.lifetime(:a)),
          R.slice({R.atom(), R.term()})
        ) :: R.nif_result(R.unit())
  defrust draw_image_impl(canvas, args, opts, raw_opts) do
    image = unwrap!(image_from_term(first_arg_term!()))
    paint = Paint.default()
    paint.set_anti_alias(true)

    case opts.opacity do
      {:some, opacity} ->
        alpha = opacity |> clamp(0.0, 1.0) |> Kernel.*(255.0) |> round() |> cast(:u8)
        paint.set_alpha(alpha)

      :none ->
        :ok
    end

    unwrap!(apply_blend_mode(mut_ref(paint), raw_opts))
    sampling = unwrap!(opt_sampling(raw_opts, Atoms.sampling()))

    source =
      case opts.source do
        {:some, term} -> some(unwrap!(rect_from_term(term)))
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
              ref(paint)
            )

          :none ->
            draw_image_source_or_default(canvas, image, source, opts, sampling, ref(paint))
        end

      :none ->
        draw_image_source_or_default(canvas, image, source, opts, sampling, ref(paint))
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
          some({ref(source), SrcRectConstraint.Strict}),
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
          R.vec(R.term()),
          GeneratedOpts.PictureOpts.t(R.lifetime(:a)),
          R.slice({R.atom(), R.term()})
        ) :: R.nif_result(R.unit())
  defrust draw_picture_impl(canvas, args, opts, raw_opts) do
    picture = unwrap!(picture_from_term(first_arg_term!()))
    paint = Paint.default()
    paint.set_anti_alias(true)

    case opts.opacity do
      {:some, opacity} ->
        alpha = opacity |> clamp(0.0, 1.0) |> Kernel.*(255.0) |> round() |> cast(:u8)
        paint.set_alpha(alpha)

      :none ->
        :ok
    end

    unwrap!(apply_blend_mode(mut_ref(paint), raw_opts))
    canvas.save()
    canvas.translate({opts.x.unwrap_or(0.0), opts.y.unwrap_or(0.0)})
    canvas.draw_picture(ref(picture), none(), some(ref(paint)))
    canvas.restore()

    :ok
  end
end
