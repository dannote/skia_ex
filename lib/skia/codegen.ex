defmodule Skia.Codegen do
  @moduledoc false

  alias RustQ.Rust.AST
  alias Skia.Codegen.Command.Registry, as: Commands
  alias Skia.Codegen.Rust.Core
  alias Skia.Codegen.Rust.Nifs
  alias Skia.Codegen.Rust.Targets
  alias Skia.Codegen.Rusty.Command
  alias Skia.Codegen.Rusty.Support

  @spec generated_targets() :: [{atom(), keyword()}]
  def generated_targets, do: Targets.all()

  @spec generated_native() :: String.t()
  def generated_native, do: Nifs.generated_native()

  @doc false
  @spec native_nif_specs() :: keyword(keyword())
  def native_nif_specs, do: Nifs.native_nif_specs()

  @spec generated_native_nifs() :: String.t()
  def generated_native_nifs, do: Nifs.generated_native_nifs()

  @spec generated_atoms() :: String.t()
  def generated_atoms, do: Core.generated_atoms()

  @spec generated_enums() :: String.t()
  def generated_enums, do: Core.generated_enums()

  @spec generated_dispatch() :: String.t()
  def generated_dispatch, do: Core.generated_dispatch()

  @spec generated_style_helpers() :: String.t()
  def generated_style_helpers, do: Core.generated_style_helpers()

  @spec generated_opts_helpers() :: String.t()
  def generated_opts_helpers, do: Core.generated_opts_helpers()

  @doc false
  @spec resource_specs() :: [{atom(), keyword()}]
  def resource_specs, do: Core.resource_specs()

  @spec generated_resources() :: String.t()
  def generated_resources, do: Core.generated_resources()

  defp generated_rust_preamble, do: Core.generated_rust_preamble()
  defp render_items(items, file), do: Core.render_items(items, file)
  defp render_rustq_item(ast), do: Core.render_rustq_item(ast)
  defp rusty_ast(module, name), do: Core.rusty_ast(module, name)

  @spec generated_layers() :: String.t()
  def generated_layers do
    items =
      (Command.Layers.generated_command_asts() ++ Command.Layers.generated_asts())
      |> Enum.map(&render_rustq_item/1)

    render_items(items, "generated_layers.rs")
  end

  @spec generated_transforms() :: String.t()
  def generated_transforms do
    generated_transform_impl_asts()
    |> Enum.map(&render_rustq_item/1)
    |> render_items("generated_transforms.rs")
  end

  @doc false
  @spec generated_transform_impl_asts() :: [AST.Function.t()]
  def generated_transform_impl_asts, do: Command.Transforms.generated_asts()

  @spec generated_shapes() :: String.t()
  def generated_shapes do
    generated_shape_impl_asts()
    |> Enum.map(&render_rustq_item/1)
    |> render_items("generated_shapes.rs")
  end

  @doc false
  @spec generated_shape_impl_asts() :: [AST.Function.t()]
  def generated_shape_impl_asts, do: Command.Shapes.generated_asts()

  @spec generated_text() :: String.t()
  def generated_text do
    Command.Text.generated_asts()
    |> Enum.map(&render_rustq_item/1)
    |> render_items("generated_text.rs")
  end

  @spec generated_images() :: String.t()
  def generated_images do
    Command.Images.generated_asts()
    |> Enum.map(&render_rustq_item/1)
    |> render_items("generated_images.rs")
  end

  @spec generated_draw_paths() :: String.t()
  def generated_draw_paths do
    Command.Paths.generated_asts()
    |> Enum.map(&render_rustq_item/1)
    |> render_items("generated_draw_paths.rs")
  end

  @spec generated_clips() :: String.t()
  def generated_clips do
    Command.Clips.generated_asts()
    |> Enum.map(&render_rustq_item/1)
    |> render_items("generated_clips.rs")
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
    |> Enum.map(&rusty_ast(Support.PaintDecoders, &1))
    |> Enum.map(&render_rustq_item/1)
    |> render_items("generated_paint.rs")
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
    |> Enum.map(&rusty_ast(Command.Paths, &1))
    |> Enum.map(&render_rustq_item/1)
    |> render_items("generated_path.rs")
  end

  @spec generated_opts() :: String.t()
  def generated_opts do
    commands =
      Commands.all()
      |> Enum.reject(fn {_name, spec} -> Keyword.get(spec, :opts, []) == [] end)
      |> Enum.flat_map(fn {name, spec} ->
        struct_name = name |> Atom.to_string() |> Macro.camelize() |> Kernel.<>("Opts")
        opts = Keyword.get(spec, :opts, [])

        RustQ.Rustler.opts_decoder(struct_name,
          lifetime: :a,
          fn: "decode_#{name}_opts",
          fields: Enum.map(opts, &opts_decoder_field/1)
        )
      end)

    opts_module_template()
    |> RustQ.render!(
      "generated_opts.rs",
      preamble: generated_rust_preamble(),
      splice: [commands: commands]
    )
  end

  defp opts_module_template do
    """
    #![allow(dead_code)]

    use rustler::{Atom, NifResult, Term};

    use super::{atoms, opt_atom_option, opt_bool_option, opt_f32, opt_f32_option, opt_term};

    __rq_commands!();
    """
  end

  defp opts_decoder_field(opt) do
    {Keyword.fetch!(opt, :name),
     [type: Keyword.fetch!(opt, :type), required: Keyword.get(opt, :required, false)]}
  end
end
