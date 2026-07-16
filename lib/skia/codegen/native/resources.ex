defmodule Skia.Codegen.Native.Resources do
  @moduledoc false

  alias RustQ.Rust.AST
  alias RustQ.Rustler.Resource

  @resources [
    EncodedImage: :decode_encoded_image_ref,
    EncodedFont: :decode_encoded_font_ref,
    EncodedPicture: :decode_encoded_picture_ref,
    EncodedTextBlob: :decode_encoded_text_blob_ref,
    EncodedRuntimeEffect: :decode_encoded_runtime_effect_ref
  ]

  @spec generated_items() :: [AST.item()]
  def generated_items do
    native_module()
    |> RustQ.Native.items()
    |> Enum.reject(&match?(%AST.TypeAlias{}, &1))
    |> Kernel.++(decoder_items())
  end

  defp decoder_items do
    Enum.map(@resources, fn {name, decoder} ->
      Resource.handle_decoder(name, decoder: decoder)
    end)
  end

  defp native_module do
    module = Skia.Codegen.Native.Resources.Generated

    if Code.ensure_loaded?(module) do
      module
    else
      Module.create(
        module,
        quote do
          use RustQ.Native,
            build: false,
            load: false,
            crate: :skia_native_resources

          alias RustQ.Type, as: R

          @type encoded_image :: %{required(:image) => R.raw(:Image)}
          @type encoded_image_resource :: R.resource(encoded_image())

          @type encoded_font :: %{required(:typeface) => R.raw(:"skia_safe::Typeface")}
          @type encoded_font_resource :: R.resource(encoded_font())

          @type encoded_picture :: %{
                  required(:bytes) => [R.u8()],
                  required(:picture) => R.raw(:Picture)
                }
          @type encoded_picture_resource :: R.resource(encoded_picture())

          @type encoded_text_blob :: %{required(:blob) => R.raw(:TextBlob)}
          @type encoded_text_blob_resource :: R.resource(encoded_text_blob())

          @type encoded_runtime_effect :: %{required(:source) => String.t()}
          @type encoded_runtime_effect_resource :: R.resource(encoded_runtime_effect())
        end,
        Macro.Env.location(__ENV__)
      )

      module
    end
  end
end
