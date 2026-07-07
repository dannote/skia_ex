defmodule Skia.Codegen.Rust.Commands do
  @moduledoc false

  alias RustQ.Rust.AST
  alias Skia.Codegen.Rust.Core
  alias Skia.Codegen.Rusty.Command
  alias Skia.Codegen.Rusty.Support

  @spec generated_layers() :: String.t()
  def generated_layers do
    items =
      (Command.Layers.generated_command_asts() ++ Command.Layers.generated_asts())
      |> Enum.map(&Core.render_rustq_item/1)

    Core.render_items(items, "generated_layers.rs")
  end

  @spec generated_transforms() :: String.t()
  def generated_transforms do
    generated_transform_impl_asts()
    |> Enum.map(&Core.render_rustq_item/1)
    |> Core.render_items("generated_transforms.rs")
  end

  @doc false
  @spec generated_transform_impl_asts() :: [AST.Function.t()]
  def generated_transform_impl_asts, do: Command.Transforms.generated_asts()

  @spec generated_shapes() :: String.t()
  def generated_shapes do
    generated_shape_impl_asts()
    |> Enum.map(&Core.render_rustq_item/1)
    |> Core.render_items("generated_shapes.rs")
  end

  @doc false
  @spec generated_shape_impl_asts() :: [AST.Function.t()]
  def generated_shape_impl_asts, do: Command.Shapes.generated_asts()

  @spec generated_text() :: String.t()
  def generated_text do
    Command.Text.generated_asts()
    |> Enum.map(&Core.render_rustq_item/1)
    |> Core.render_items("generated_text.rs")
  end

  @spec generated_images() :: String.t()
  def generated_images do
    Command.Images.generated_asts()
    |> Enum.map(&Core.render_rustq_item/1)
    |> Core.render_items("generated_images.rs")
  end

  @spec generated_draw_paths() :: String.t()
  def generated_draw_paths do
    Command.Paths.generated_asts()
    |> Enum.map(&Core.render_rustq_item/1)
    |> Core.render_items("generated_draw_paths.rs")
  end

  @spec generated_clips() :: String.t()
  def generated_clips do
    Command.Clips.generated_asts()
    |> Enum.map(&Core.render_rustq_item/1)
    |> Core.render_items("generated_clips.rs")
  end

  @spec generated_paint() :: String.t()
  def generated_paint do
    [
      :decode_path_1d_style,
      :optional_matrix_from_term,
      :optional_rect_from_term,
      :optional_image_filter_from_term,
      :runtime_uniform_data,
      :runtime_children,
      :decode_paint,
      :decode_linear_gradient_paint,
      :decode_two_point_conical_gradient_paint,
      :decode_color_shader_paint,
      :decode_radial_gradient_paint,
      :decode_sweep_gradient_paint,
      :decode_runtime_effect_shader_paint,
      :decode_image_shader_paint,
      :decode_picture_shader_paint,
      :decode_color_filter,
      :decode_matrix_color_filter,
      :decode_compose_color_filter,
      :decode_image_filter,
      :decode_compose_image_filter,
      :decode_offset_image_filter,
      :decode_drop_shadow_image_filter,
      :decode_color_filter_image_filter,
      :decode_shader_image_filter,
      :decode_magnifier_image_filter,
      :decode_matrix_convolution_image_filter,
      :decode_matrix_transform_image_filter,
      :decode_merge_image_filter,
      :decode_tile_image_filter,
      :decode_morphology_image_filter,
      :decode_shader,
      :decode_mask_filter,
      :decode_path_effect,
      :decode_corner_path_effect,
      :decode_trim_path_effect,
      :decode_discrete_path_effect,
      :decode_path_1d_effect,
      :decode_line_2d_path_effect,
      :decode_binary_path_effect,
      :decode_sampling_options,
      :decode_sampling_cubic_or_aniso,
      :decode_color,
      :decode_rgba_color,
      :decode_gradient_stops
    ]
    |> Enum.map(&Core.rusty_ast(Support.PaintDecoders, &1))
    |> Enum.map(&Core.render_rustq_item/1)
    |> Core.render_items("generated_paint.rs")
  end

  @spec generated_path() :: String.t()
  def generated_path do
    [
      :decode_path_direction,
      :build_path,
      :build_path_from_compact_tuple,
      :build_path_from_svg_field,
      :build_path_from_segments_field,
      :build_compact_path
    ]
    |> Enum.map(&Core.rusty_ast(Command.Paths, &1))
    |> Enum.map(&Core.render_rustq_item/1)
    |> Core.render_items("generated_path.rs")
  end
end
