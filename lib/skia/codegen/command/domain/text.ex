defmodule Skia.Codegen.Command.Domain.Text do
  @moduledoc false

  alias Skia.Codegen.Command.SpecReader, as: CommandSpecs

  @type color :: Skia.Command.color()
  @type blend_mode :: RustQ.Type.enum(:blend_mode)
  @type stroke_cap :: RustQ.Type.enum(:stroke_cap)
  @type stroke_join :: RustQ.Type.enum(:stroke_join)
  @type font :: term()

  @metadata %{
    text_blob: [handler: :draw_text_blob, defaults: [fill: :black]],
    text: [handler: :draw_text, defaults: [size: 16, fill: :black]]
  }

  @type paint_opts :: %{
          optional(:paint) => Skia.Paint.t(),
          optional(:fill) => color(),
          optional(:stroke) => color(),
          optional(:stroke_width) => RustQ.Type.f32(),
          optional(:stroke_cap) => stroke_cap(),
          optional(:stroke_join) => stroke_join(),
          optional(:stroke_miter) => RustQ.Type.f32(),
          optional(:blend_mode) => blend_mode(),
          optional(:image_filter) => Skia.ImageFilter.t(),
          optional(:path_effect) => Skia.PathEffect.t(),
          optional(:color_filter) => Skia.ColorFilter.t(),
          optional(:mask_filter) => Skia.MaskFilter.t()
        }

  @type text_blob_opts :: %{
          required(:x) => RustQ.Type.f32(),
          required(:y) => RustQ.Type.f32(),
          optional(:paint) => Skia.Paint.t(),
          optional(:fill) => color(),
          optional(:stroke) => color(),
          optional(:stroke_width) => RustQ.Type.f32(),
          optional(:stroke_cap) => stroke_cap(),
          optional(:stroke_join) => stroke_join(),
          optional(:stroke_miter) => RustQ.Type.f32(),
          optional(:blend_mode) => blend_mode(),
          optional(:image_filter) => Skia.ImageFilter.t(),
          optional(:path_effect) => Skia.PathEffect.t(),
          optional(:color_filter) => Skia.ColorFilter.t(),
          optional(:mask_filter) => Skia.MaskFilter.t()
        }

  @type text_opts :: %{
          required(:x) => RustQ.Type.f32(),
          required(:y) => RustQ.Type.f32(),
          optional(:width) => RustQ.Type.f32(),
          optional(:size) => RustQ.Type.f32(),
          optional(:fill) => color(),
          optional(:font) => font(),
          optional(:weight) => integer(),
          optional(:align) => atom(),
          optional(:direction) => atom(),
          optional(:font_family) => String.t(),
          optional(:line_height) => RustQ.Type.f32(),
          optional(:spans) => term()
        }

  @spec commands() :: keyword()
  def commands do
    __ENV__.file
    |> CommandSpecs.from_file()
    |> Enum.map(fn command ->
      {command.name,
       @metadata
       |> Map.fetch!(command.name)
       |> Keyword.merge(args: command.args, opts: command.opts)}
    end)
  end

  @spec text_blob(Skia.Document.t(), Skia.TextBlob.t(), text_blob_opts()) :: Skia.Document.t()
  def text_blob(document, blob, opts), do: keep_command_shape(document, blob, opts)

  @spec text(Skia.Document.t(), String.t(), text_opts()) :: Skia.Document.t()
  def text(document, text, opts), do: keep_command_shape(document, text, opts)

  defp keep_command_shape(document, _arg, _opts), do: document
end
