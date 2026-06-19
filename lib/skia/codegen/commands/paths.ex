defmodule Skia.Codegen.Commands.Paths do
  @moduledoc false

  alias Skia.Codegen.CommandSpecs

  @type color :: Skia.Command.color()
  @type blend_mode :: RustQ.Type.enum(:blend_mode)
  @type stroke_cap :: RustQ.Type.enum(:stroke_cap)
  @type stroke_join :: RustQ.Type.enum(:stroke_join)
  @type fill_rule :: RustQ.Type.enum(:fill_rule)
  @type path_op :: RustQ.Type.enum(:path_op)

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

  @type path_opts :: %{
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
          optional(:mask_filter) => Skia.MaskFilter.t(),
          optional(:fill_rule) => fill_rule()
        }

  @type path_op_opts :: %{
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
          optional(:mask_filter) => Skia.MaskFilter.t(),
          required(:path_op) => path_op(),
          optional(:fill_rule) => fill_rule()
        }

  @type path_outline_opts :: %{
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
          optional(:mask_filter) => Skia.MaskFilter.t(),
          required(:outline_width) => RustQ.Type.f32(),
          optional(:fill_rule) => fill_rule()
        }

  @spec commands() :: keyword()
  def commands, do: CommandSpecs.command_metadata_from_file(__ENV__.file, "draw")

  @spec path(Skia.Document.t(), Skia.Path.t(), path_opts()) :: Skia.Document.t()
  def path(document, path, opts), do: keep_command_shape(document, path, opts)

  @spec path_op(Skia.Document.t(), Skia.Path.t(), Skia.Path.t(), path_op_opts()) ::
          Skia.Document.t()
  def path_op(document, a, b, opts), do: keep_command_shape(document, a, b, opts)

  @spec path_outline(Skia.Document.t(), Skia.Path.t(), path_outline_opts()) :: Skia.Document.t()
  def path_outline(document, path, opts), do: keep_command_shape(document, path, opts)

  defp keep_command_shape(document, _arg, _opts), do: document
  defp keep_command_shape(document, _a, _b, _opts), do: document
end
