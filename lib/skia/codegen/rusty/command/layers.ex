defmodule Skia.Codegen.Rusty.Command.Layers do
  @moduledoc """
  Rusty Elixir layer implementation generation.

  Save/restore and semantic layer implementations live here.
  """

  alias Skia.Codegen.Command.Domain.Layers

  @simple_commands [:save, :restore]

  @spec generated_command_asts() :: [RustQ.Rust.AST.Function.t()]
  def generated_command_asts do
    Layers.commands()
    |> Keyword.take(@simple_commands)
    |> Enum.map(fn {_name, spec} -> spec |> Keyword.fetch!(:handler) |> rust_ast!() end)
  end

  use Skia.Codegen.Rusty.CommandDomain,
    from: Layers,
    commands: [:save_layer],
    rust_packages: [{"skia-safe", [manifest_path: "native/skia_native/Cargo.toml"]}]

  alias RustQ.Type, as: R

  @spec draw_save(R.ref(SkiaSafe.Canvas.t()), term()) :: R.nif_result(R.unit())
  defrust draw_save(canvas, _command) do
    canvas.save()
    :ok
  end

  @spec draw_restore(R.ref(SkiaSafe.Canvas.t()), term()) :: R.nif_result(R.unit())
  defrust draw_restore(canvas, _command) do
    canvas.restore()
    :ok
  end

  @spec draw_save_layer_impl(
          R.ref(SkiaSafe.Canvas.t()),
          GeneratedOpts.SaveLayerOpts.t(R.lifetime(:a)),
          R.slice({atom(), term()})
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
    apply_blend_mode(paint, raw_opts)

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
        filter = decode_image_filter(term)
        paint.set_image_filter(filter)

      :none ->
        :ok
    end

    rec = SaveLayerRec.default().paint(paint)

    rec =
      case bounds.as_ref() do
        {:some, bounds} -> rec.bounds(bounds)
        :none -> rec
      end

    canvas.save_layer(rec)

    :ok
  end
end
