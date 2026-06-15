defmodule Skia.CommandSpec.Types do
  @moduledoc false

  def color, do: :color
  def image_filter, do: :image_filter
  def blend_mode, do: {:enum, :blend_mode, skia: "SkBlendMode", rust: :BlendMode}
  def sampling, do: {:enum, :sampling, skia: "SkFilterMode", rust: :FilterMode}
  def tile_mode, do: {:enum, :tile_mode, skia: "SkTileMode", rust: :TileMode}
  def stroke_cap, do: {:enum, :stroke_cap, skia: "SkPaint_Cap", rust: "paint::Cap"}
  def stroke_join, do: {:enum, :stroke_join, skia: "SkPaint_Join", rust: "paint::Join"}
  def fill_rule, do: {:enum, :fill_rule, skia: "SkPathFillType", rust: :PathFillType}
  def path_op, do: {:enum, :path_op, skia: "SkPathOp", rust: :PathOp}

  def rect_opts do
    [
      [name: :x, type: :number, required: true],
      [name: :y, type: :number, required: true],
      [name: :width, type: :number, required: true],
      [name: :height, type: :number, required: true]
    ]
  end

  def paint_opts do
    [
      [name: :fill, type: color()],
      [name: :stroke, type: color()],
      [name: :stroke_width, type: :number],
      [name: :stroke_cap, type: stroke_cap()],
      [name: :stroke_join, type: stroke_join()],
      [name: :stroke_miter, type: :number],
      [name: :blend_mode, type: blend_mode()]
    ]
  end
end
