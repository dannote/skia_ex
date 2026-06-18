defmodule Skia.Codegen.Rusty.Layers do
  @moduledoc """
  Rusty Elixir layer implementation generation.

  Simple save/restore commands stay in `Skia.Codegen.GeneratedLayers`; semantic
  layer implementations live here.
  """

  alias RustQ.Rust.AST
  alias Skia.CommandSpec.Layers

  @commands [:save_layer]

  @spec commands() :: [atom()]
  def commands, do: @commands

  @spec generated_asts() :: [AST.Function.t()]
  def generated_asts do
    Layers.commands()
    |> Keyword.take(@commands)
    |> Enum.map(fn {_name, spec} -> spec |> Keyword.fetch!(:handler) |> impl_ast!() end)
  end

  defp impl_ast!(handler) do
    name = String.to_atom("#{handler}_impl")

    Enum.find(__rustq_asts__(), &(&1.name == name)) ||
      raise "missing Rusty layer impl #{name}"
  end

  use RustQ.Meta

  alias RustQ.Type, as: R

  @spec draw_save_layer_impl(
          R.ref(SkiaSafe.Canvas.t()),
          GeneratedOpts.SaveLayerOpts.t(R.lifetime(:a)),
          R.slice({R.atom(), R.term()})
        ) :: R.nif_result(R.unit())
  defrust draw_save_layer_impl(canvas, opts, raw_opts) do
    bounds =
      case opts.bounds do
        {:some, term} -> some(unwrap!(rect_from_term(term)))
        :none -> none()
      end

    paint = Paint.default()

    alpha =
      opts.opacity.unwrap_or(1.0)
      |> clamp(0.0, 1.0)
      |> Kernel.*(255.0)
      |> round()
      |> cast(:u8)

    paint.set_alpha(alpha)
    unwrap!(apply_blend_mode(mut_ref(paint), raw_opts))

    case opts.blur do
      {:some, sigma} ->
        case ImageFilters.blur({sigma, sigma}, TileMode.Decal, none(), none()) do
          {:some, filter} -> paint.set_image_filter(filter)
          :none -> :ok
        end

      :none ->
        :ok
    end

    case opts.image_filter do
      {:some, term} ->
        filter = unwrap!(decode_image_filter(term))
        paint.set_image_filter(filter)

      :none ->
        :ok
    end

    rec = SaveLayerRec.default().paint(ref(paint))

    rec =
      case bounds.as_ref() do
        {:some, bounds} -> rec.bounds(bounds)
        :none -> rec
      end

    canvas.save_layer(ref(rec))

    :ok
  end
end
