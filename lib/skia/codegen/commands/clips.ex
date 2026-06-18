defmodule Skia.Codegen.Commands.Clips do
  @moduledoc false

  @type clip_op :: :difference | :intersect
  @type fill_rule :: :winding | :even_odd | :inverse_winding | :inverse_even_odd

  @defaults %{
    clip_rect: [radius: 0, antialias: true, clip_op: :intersect],
    clip_circle: [antialias: true, clip_op: :intersect],
    clip_path: [antialias: true, fill_rule: :winding, clip_op: :intersect]
  }

  @type clip_rect_opts :: %{
          required(:x) => RustQ.Type.f32(),
          required(:y) => RustQ.Type.f32(),
          required(:width) => RustQ.Type.f32(),
          required(:height) => RustQ.Type.f32(),
          optional(:radius) => RustQ.Type.f32(),
          optional(:antialias) => boolean(),
          optional(:clip_op) => clip_op()
        }

  @type clip_circle_opts :: %{
          required(:x) => RustQ.Type.f32(),
          required(:y) => RustQ.Type.f32(),
          required(:radius) => RustQ.Type.f32(),
          optional(:antialias) => boolean(),
          optional(:clip_op) => clip_op()
        }

  @type clip_path_opts :: %{
          optional(:antialias) => boolean(),
          optional(:fill_rule) => fill_rule(),
          optional(:clip_op) => clip_op()
        }

  @spec commands() :: keyword()
  def commands do
    __ENV__.file
    |> Skia.Codegen.CommandSpecs.from_file()
    |> Enum.map(fn command ->
      {command.name,
       [
         handler: command.name,
         args: command.args,
         opts: command.opts,
         defaults: Map.get(@defaults, command.name, [])
       ]}
    end)
  end

  @spec clip_rect(Skia.Document.t(), clip_rect_opts()) :: Skia.Document.t()
  def clip_rect(document, opts), do: {document, opts}

  @spec clip_circle(Skia.Document.t(), clip_circle_opts()) :: Skia.Document.t()
  def clip_circle(document, opts), do: {document, opts}

  @spec clip_path(Skia.Document.t(), Skia.Path.t(), clip_path_opts()) :: Skia.Document.t()
  def clip_path(document, path, opts), do: {document, path, opts}
end
