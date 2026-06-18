defmodule Skia.Codegen.Commands.Shapes do
  @moduledoc false

  @type color :: Skia.Command.color()
  @type blend_mode :: atom()
  @type stroke_cap :: atom()
  @type stroke_join :: atom()
  @type point :: {number(), number()}

  @native_refs %{
    clear: ["skia_safe::Canvas::clear"],
    rect: ["skia_safe::Canvas::draw_rect", "skia_safe::Canvas::draw_rrect"],
    oval: ["skia_safe::Canvas::draw_oval"],
    arc: ["skia_safe::Canvas::draw_arc"],
    circle: ["skia_safe::Canvas::draw_circle"],
    vertices: ["skia_safe::Canvas::draw_vertices"],
    line: ["skia_safe::Canvas::draw_line"]
  }

  @defaults %{
    rect: [radius: 0],
    arc: [use_center: false],
    vertices: [blend_mode: :src_over]
  }

  @type paint_opts :: %{
          optional(:paint) => Skia.Paint.t(),
          optional(:fill) => color(),
          optional(:stroke) => color(),
          optional(:stroke_width) => number(),
          optional(:stroke_cap) => stroke_cap(),
          optional(:stroke_join) => stroke_join(),
          optional(:stroke_miter) => number(),
          optional(:blend_mode) => blend_mode(),
          optional(:image_filter) => Skia.ImageFilter.t(),
          optional(:path_effect) => Skia.PathEffect.t(),
          optional(:color_filter) => Skia.ColorFilter.t(),
          optional(:mask_filter) => Skia.MaskFilter.t()
        }

  @type clear_opts :: %{}

  @type rect_opts :: %{
          required(:x) => number(),
          required(:y) => number(),
          required(:width) => number(),
          required(:height) => number(),
          optional(:radius) => number(),
          optional(:paint) => Skia.Paint.t(),
          optional(:fill) => color(),
          optional(:stroke) => color(),
          optional(:stroke_width) => number(),
          optional(:stroke_cap) => stroke_cap(),
          optional(:stroke_join) => stroke_join(),
          optional(:stroke_miter) => number(),
          optional(:blend_mode) => blend_mode(),
          optional(:image_filter) => Skia.ImageFilter.t(),
          optional(:path_effect) => Skia.PathEffect.t(),
          optional(:color_filter) => Skia.ColorFilter.t(),
          optional(:mask_filter) => Skia.MaskFilter.t()
        }

  @type oval_opts :: %{
          required(:x) => number(),
          required(:y) => number(),
          required(:width) => number(),
          required(:height) => number(),
          optional(:paint) => Skia.Paint.t(),
          optional(:fill) => color(),
          optional(:stroke) => color(),
          optional(:stroke_width) => number(),
          optional(:stroke_cap) => stroke_cap(),
          optional(:stroke_join) => stroke_join(),
          optional(:stroke_miter) => number(),
          optional(:blend_mode) => blend_mode(),
          optional(:image_filter) => Skia.ImageFilter.t(),
          optional(:path_effect) => Skia.PathEffect.t(),
          optional(:color_filter) => Skia.ColorFilter.t(),
          optional(:mask_filter) => Skia.MaskFilter.t()
        }

  @type arc_opts :: %{
          required(:x) => number(),
          required(:y) => number(),
          required(:width) => number(),
          required(:height) => number(),
          required(:start_degrees) => number(),
          required(:sweep_degrees) => number(),
          optional(:use_center) => boolean(),
          optional(:paint) => Skia.Paint.t(),
          optional(:fill) => color(),
          optional(:stroke) => color(),
          optional(:stroke_width) => number(),
          optional(:stroke_cap) => stroke_cap(),
          optional(:stroke_join) => stroke_join(),
          optional(:stroke_miter) => number(),
          optional(:blend_mode) => blend_mode(),
          optional(:image_filter) => Skia.ImageFilter.t(),
          optional(:path_effect) => Skia.PathEffect.t(),
          optional(:color_filter) => Skia.ColorFilter.t(),
          optional(:mask_filter) => Skia.MaskFilter.t()
        }

  @type circle_opts :: %{
          required(:x) => number(),
          required(:y) => number(),
          required(:radius) => number(),
          optional(:paint) => Skia.Paint.t(),
          optional(:fill) => color(),
          optional(:stroke) => color(),
          optional(:stroke_width) => number(),
          optional(:stroke_cap) => stroke_cap(),
          optional(:stroke_join) => stroke_join(),
          optional(:stroke_miter) => number(),
          optional(:blend_mode) => blend_mode(),
          optional(:image_filter) => Skia.ImageFilter.t(),
          optional(:path_effect) => Skia.PathEffect.t(),
          optional(:color_filter) => Skia.ColorFilter.t(),
          optional(:mask_filter) => Skia.MaskFilter.t()
        }

  @type vertices_opts :: paint_opts()

  @type line_opts :: %{
          required(:from) => point(),
          required(:to) => point(),
          required(:stroke) => color(),
          optional(:stroke_width) => number(),
          optional(:stroke_cap) => stroke_cap(),
          optional(:stroke_join) => stroke_join(),
          optional(:stroke_miter) => number(),
          optional(:blend_mode) => blend_mode()
        }

  @spec commands() :: keyword()
  def commands do
    __ENV__.file
    |> Skia.Codegen.CommandSchema.from_file()
    |> Enum.map(fn command ->
      {command.name,
       [
         handler: handler(command.name),
         args: command.args,
         opts: command.opts,
         defaults: Map.get(@defaults, command.name, []),
         native_refs: Map.fetch!(@native_refs, command.name)
       ]}
    end)
  end

  defp handler(name), do: String.to_atom("draw_#{name}")

  @spec clear(Skia.Document.t(), color(), clear_opts()) :: Skia.Document.t()
  def clear(document, color, opts), do: {document, color, opts}

  @spec rect(Skia.Document.t(), rect_opts()) :: Skia.Document.t()
  def rect(document, opts), do: {document, opts}

  @spec oval(Skia.Document.t(), oval_opts()) :: Skia.Document.t()
  def oval(document, opts), do: {document, opts}

  @spec arc(Skia.Document.t(), arc_opts()) :: Skia.Document.t()
  def arc(document, opts), do: {document, opts}

  @spec circle(Skia.Document.t(), circle_opts()) :: Skia.Document.t()
  def circle(document, opts), do: {document, opts}

  @spec vertices(Skia.Document.t(), Skia.Vertices.t(), vertices_opts()) :: Skia.Document.t()
  def vertices(document, vertices, opts), do: {document, vertices, opts}

  @spec line(Skia.Document.t(), line_opts()) :: Skia.Document.t()
  def line(document, opts), do: {document, opts}
end
