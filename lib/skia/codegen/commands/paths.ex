defmodule Skia.Codegen.Commands.Paths do
  @moduledoc false

  @type color :: Skia.Command.color()
  @type blend_mode :: atom()
  @type stroke_cap :: atom()
  @type stroke_join :: atom()
  @type fill_rule :: :winding | :even_odd | :inverse_winding | :inverse_even_odd
  @type path_op :: :difference | :intersect | :union | :xor | :reverse_difference

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

  @type path_opts :: %{
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
          optional(:mask_filter) => Skia.MaskFilter.t(),
          optional(:fill_rule) => fill_rule()
        }

  @type path_op_opts :: %{
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
          optional(:mask_filter) => Skia.MaskFilter.t(),
          required(:path_op) => path_op(),
          optional(:fill_rule) => fill_rule()
        }

  @type path_outline_opts :: %{
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
          optional(:mask_filter) => Skia.MaskFilter.t(),
          required(:outline_width) => number(),
          optional(:fill_rule) => fill_rule()
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
         opts: command.opts
       ]}
    end)
  end

  defp handler(name), do: String.to_atom("draw_#{name}")

  @spec path(Skia.Document.t(), Skia.Path.t(), path_opts()) :: Skia.Document.t()
  def path(document, path, opts), do: {document, path, opts}

  @spec path_op(Skia.Document.t(), Skia.Path.t(), Skia.Path.t(), path_op_opts()) ::
          Skia.Document.t()
  def path_op(document, a, b, opts), do: {document, a, b, opts}

  @spec path_outline(Skia.Document.t(), Skia.Path.t(), path_outline_opts()) :: Skia.Document.t()
  def path_outline(document, path, opts), do: {document, path, opts}
end
