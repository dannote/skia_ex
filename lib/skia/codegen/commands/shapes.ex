defmodule Skia.Codegen.Commands.Shapes do
  @moduledoc false

  alias Skia.Codegen.CommandSpecs

  @type color :: Skia.Command.color()
  @type blend_mode :: RustQ.Type.enum(:blend_mode)
  @type stroke_cap :: RustQ.Type.enum(:stroke_cap)
  @type stroke_join :: RustQ.Type.enum(:stroke_join)
  @type point :: {RustQ.Type.f32(), RustQ.Type.f32()}

  @defaults %{
    rect: [radius: 0],
    arc: [use_center: false],
    vertices: [blend_mode: :src_over]
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

  @type clear_opts :: %{}

  @type rect_opts :: %{
          required(:x) => RustQ.Type.f32(),
          required(:y) => RustQ.Type.f32(),
          required(:width) => RustQ.Type.f32(),
          required(:height) => RustQ.Type.f32(),
          optional(:radius) => RustQ.Type.f32(),
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

  @type oval_opts :: %{
          required(:x) => RustQ.Type.f32(),
          required(:y) => RustQ.Type.f32(),
          required(:width) => RustQ.Type.f32(),
          required(:height) => RustQ.Type.f32(),
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

  @type arc_opts :: %{
          required(:x) => RustQ.Type.f32(),
          required(:y) => RustQ.Type.f32(),
          required(:width) => RustQ.Type.f32(),
          required(:height) => RustQ.Type.f32(),
          required(:start_degrees) => RustQ.Type.f32(),
          required(:sweep_degrees) => RustQ.Type.f32(),
          optional(:use_center) => boolean(),
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

  @type circle_opts :: %{
          required(:x) => RustQ.Type.f32(),
          required(:y) => RustQ.Type.f32(),
          required(:radius) => RustQ.Type.f32(),
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

  @type vertices_opts :: paint_opts()

  @type line_opts :: %{
          required(:from) => point(),
          required(:to) => point(),
          required(:stroke) => color(),
          optional(:stroke_width) => RustQ.Type.f32(),
          optional(:stroke_cap) => stroke_cap(),
          optional(:stroke_join) => stroke_join(),
          optional(:stroke_miter) => RustQ.Type.f32(),
          optional(:blend_mode) => blend_mode()
        }

  @spec commands() :: keyword()
  def commands do
    __ENV__.file
    |> CommandSpecs.from_file()
    |> Enum.map(fn command ->
      {command.name,
       [
         handler: handler(command.name),
         args: command.args,
         opts: command.opts,
         defaults: Map.get(@defaults, command.name, [])
       ]}
    end)
  end

  defp handler(name), do: Skia.Codegen.Atom.identifier!("draw_#{name}")

  @spec clear(Skia.Document.t(), color(), clear_opts()) :: Skia.Document.t()
  def clear(document, color, opts), do: keep_command_shape(document, color, opts)

  @spec rect(Skia.Document.t(), rect_opts()) :: Skia.Document.t()
  def rect(document, opts), do: keep_command_shape(document, opts)

  @spec oval(Skia.Document.t(), oval_opts()) :: Skia.Document.t()
  def oval(document, opts), do: keep_command_shape(document, opts)

  @spec arc(Skia.Document.t(), arc_opts()) :: Skia.Document.t()
  def arc(document, opts), do: keep_command_shape(document, opts)

  @spec circle(Skia.Document.t(), circle_opts()) :: Skia.Document.t()
  def circle(document, opts), do: keep_command_shape(document, opts)

  @spec vertices(Skia.Document.t(), Skia.Vertices.t(), vertices_opts()) :: Skia.Document.t()
  def vertices(document, vertices, opts), do: keep_command_shape(document, vertices, opts)

  @spec line(Skia.Document.t(), line_opts()) :: Skia.Document.t()
  def line(document, opts), do: keep_command_shape(document, opts)

  defp keep_command_shape(document, _opts), do: document
  defp keep_command_shape(document, _arg, _opts), do: document
end
