defmodule Skia.Codegen.Commands.Images do
  @moduledoc false

  @type blend_mode :: atom()
  @type source_rect :: {number(), number(), number(), number()}

  @metadata %{
    image: [
      handler: :draw_image,
      native_refs: [
        "skia_safe::Canvas::draw_image_with_sampling_options",
        "skia_safe::Canvas::draw_image_rect_with_sampling_options"
      ]
    ],
    picture: [
      handler: :draw_picture,
      defaults: [x: 0, y: 0],
      native_refs: ["skia_safe::Canvas::draw_picture"]
    ]
  }

  @type image_opts :: %{
          required(:x) => number(),
          required(:y) => number(),
          optional(:width) => number(),
          optional(:height) => number(),
          optional(:source) => source_rect(),
          optional(:opacity) => number(),
          optional(:sampling) => Skia.SamplingOptions.t(),
          optional(:blend_mode) => blend_mode()
        }

  @type picture_opts :: %{
          optional(:x) => number(),
          optional(:y) => number(),
          optional(:opacity) => number(),
          optional(:blend_mode) => blend_mode()
        }

  @spec commands() :: keyword()
  def commands do
    __ENV__.file
    |> Skia.Codegen.CommandSchema.from_file()
    |> Enum.map(fn command ->
      {command.name,
       @metadata
       |> Map.fetch!(command.name)
       |> Keyword.merge(args: command.args, opts: command.opts)}
    end)
  end

  @spec image(Skia.Document.t(), Skia.Image.t(), image_opts()) :: Skia.Document.t()
  def image(document, image, opts), do: {document, image, opts}

  @spec picture(Skia.Document.t(), Skia.Picture.t(), picture_opts()) :: Skia.Document.t()
  def picture(document, picture, opts), do: {document, picture, opts}
end
