defmodule Skia.Codegen.Command.Domain.Layers do
  @moduledoc false

  alias Skia.Codegen.Command.SpecReader, as: CommandSpecs

  @type blend_mode :: RustQ.Type.enum(:blend_mode)
  @type bounds :: {RustQ.Type.f32(), RustQ.Type.f32(), RustQ.Type.f32(), RustQ.Type.f32()}

  @metadata %{
    save: [handler: :draw_save],
    save_layer: [handler: :draw_save_layer, defaults: [opacity: 1.0]],
    restore: [handler: :draw_restore],
    push_style: [],
    pop_style: []
  }

  @type empty_opts :: %{}
  @type save_layer_opts :: %{
          optional(:opacity) => RustQ.Type.f32(),
          optional(:bounds) => bounds(),
          optional(:blend_mode) => blend_mode(),
          optional(:blur) => RustQ.Type.f32(),
          optional(:image_filter) => Skia.ImageFilter.t()
        }
  @type push_style_opts :: %{required(:style) => term()}

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

  @spec save(Skia.Document.t(), empty_opts()) :: Skia.Document.t()
  def save(document, opts), do: keep_command_shape(document, opts)

  @spec save_layer(Skia.Document.t(), save_layer_opts()) :: Skia.Document.t()
  def save_layer(document, opts), do: keep_command_shape(document, opts)

  @spec restore(Skia.Document.t(), empty_opts()) :: Skia.Document.t()
  def restore(document, opts), do: keep_command_shape(document, opts)

  @spec push_style(Skia.Document.t(), push_style_opts()) :: Skia.Document.t()
  def push_style(document, opts), do: keep_command_shape(document, opts)

  @spec pop_style(Skia.Document.t(), empty_opts()) :: Skia.Document.t()
  def pop_style(document, opts), do: keep_command_shape(document, opts)

  defp keep_command_shape(document, _opts), do: document
end
