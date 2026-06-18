defmodule Skia.Codegen.Commands.Layers do
  @moduledoc false

  @type blend_mode :: atom()
  @type bounds :: {number(), number(), number(), number()}

  @metadata %{
    save: [handler: :draw_save],
    save_layer: [handler: :draw_save_layer, defaults: [opacity: 1.0]],
    restore: [handler: :draw_restore],
    push_style: [],
    pop_style: []
  }

  @type empty_opts :: %{}
  @type save_layer_opts :: %{
          optional(:opacity) => number(),
          optional(:bounds) => bounds(),
          optional(:blend_mode) => blend_mode(),
          optional(:blur) => number(),
          optional(:image_filter) => Skia.ImageFilter.t()
        }
  @type push_style_opts :: %{required(:style) => term()}

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

  @spec save(Skia.Document.t(), empty_opts()) :: Skia.Document.t()
  def save(document, opts), do: {document, opts}

  @spec save_layer(Skia.Document.t(), save_layer_opts()) :: Skia.Document.t()
  def save_layer(document, opts), do: {document, opts}

  @spec restore(Skia.Document.t(), empty_opts()) :: Skia.Document.t()
  def restore(document, opts), do: {document, opts}

  @spec push_style(Skia.Document.t(), push_style_opts()) :: Skia.Document.t()
  def push_style(document, opts), do: {document, opts}

  @spec pop_style(Skia.Document.t(), empty_opts()) :: Skia.Document.t()
  def pop_style(document, opts), do: {document, opts}
end
