defmodule Skia.Codegen.Commands.Images do
  @moduledoc false

  alias Skia.Codegen.CommandSpecs

  @type blend_mode :: RustQ.Type.enum(:blend_mode)
  @type source_rect :: {RustQ.Type.f32(), RustQ.Type.f32(), RustQ.Type.f32(), RustQ.Type.f32()}

  @metadata %{
    image: [handler: :draw_image],
    picture: [handler: :draw_picture, defaults: [x: 0, y: 0]]
  }

  @type image_opts :: %{
          required(:x) => RustQ.Type.f32(),
          required(:y) => RustQ.Type.f32(),
          optional(:width) => RustQ.Type.f32(),
          optional(:height) => RustQ.Type.f32(),
          optional(:source) => source_rect(),
          optional(:opacity) => RustQ.Type.f32(),
          optional(:sampling) => Skia.SamplingOptions.t(),
          optional(:blend_mode) => blend_mode()
        }

  @type picture_opts :: %{
          optional(:x) => RustQ.Type.f32(),
          optional(:y) => RustQ.Type.f32(),
          optional(:opacity) => RustQ.Type.f32(),
          optional(:blend_mode) => blend_mode()
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

  @spec image(Skia.Document.t(), Skia.Image.t(), image_opts()) :: Skia.Document.t()
  def image(document, image, opts), do: keep_command_shape(document, image, opts)

  @spec picture(Skia.Document.t(), Skia.Picture.t(), picture_opts()) :: Skia.Document.t()
  def picture(document, picture, opts), do: keep_command_shape(document, picture, opts)

  defp keep_command_shape(document, _arg, _opts), do: document
end
