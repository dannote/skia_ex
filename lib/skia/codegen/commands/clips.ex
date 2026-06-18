defmodule Skia.Codegen.Commands.Clips do
  @moduledoc false

  @type clip_op :: :difference | :intersect
  @type fill_rule :: :winding | :even_odd | :inverse_winding | :inverse_even_odd

  @native_refs %{
    clip_rect: ["skia_safe::Canvas::clip_rect", "skia_safe::Canvas::clip_rrect"],
    clip_circle: ["skia_safe::Canvas::clip_path"],
    clip_path: ["skia_safe::Canvas::clip_path"]
  }

  @defaults %{
    clip_rect: [radius: 0, antialias: true, clip_op: :intersect],
    clip_circle: [antialias: true, clip_op: :intersect],
    clip_path: [antialias: true, fill_rule: :winding, clip_op: :intersect]
  }

  @type clip_rect_opts :: %{
          required(:x) => number(),
          required(:y) => number(),
          required(:width) => number(),
          required(:height) => number(),
          optional(:radius) => number(),
          optional(:antialias) => boolean(),
          optional(:clip_op) => clip_op()
        }

  @type clip_circle_opts :: %{
          required(:x) => number(),
          required(:y) => number(),
          required(:radius) => number(),
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
    |> Skia.Codegen.CommandSchema.from_file()
    |> Enum.map(fn command ->
      {command.name,
       [
         handler: command.name,
         args: command.args,
         opts: command.opts,
         defaults: Map.get(@defaults, command.name, []),
         native_refs: Map.fetch!(@native_refs, command.name)
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
