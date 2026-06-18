defmodule Skia.Codegen.EnumSpecs do
  @moduledoc false

  @command_specs %{
    blend_mode: [skia: "SkBlendMode", rust: :BlendMode],
    stroke_cap: [skia: "SkPaint_Cap", rust: "paint::Cap"],
    stroke_join: [skia: "SkPaint_Join", rust: "paint::Join"],
    fill_rule: [skia: "SkPathFillType", rust: :PathFillType],
    path_op: [skia: "SkPathOp", rust: :PathOp],
    clip_op: [skia: "SkClipOp", rust: :ClipOp]
  }

  @extra_specs %{
    encoded_image_format: [skia: "SkEncodedImageFormat", rust: :EncodedImageFormat],
    blur_style: [skia: "SkBlurStyle", rust: :BlurStyle],
    sampling: [skia: "SkFilterMode", rust: :FilterMode],
    tile_mode: [skia: "SkTileMode", rust: :TileMode],
    mipmap_mode: [skia: "SkMipmapMode", rust: :MipmapMode]
  }

  @spec command_spec(atom()) :: {:ok, keyword()} | :error
  def command_spec(name), do: Map.fetch(@command_specs, name)

  @spec extra_specs() :: %{atom() => keyword()}
  def extra_specs, do: @extra_specs
end
