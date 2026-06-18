defmodule Skia.Codegen do
  @moduledoc false

  alias RustQ.Rust
  alias RustQ.Rust.AST
  alias RustQ.Rust.AST.Builder, as: A
  alias RustQ.Rustler.Decode, as: R
  alias Skia.Codegen.ShapeImpls
  alias Skia.Codegen.SkiaSafe
  alias Skia.Codegen.TransformImpls
  alias Skia.CommandSpec.Clips
  alias Skia.CommandSpec.Images
  alias Skia.CommandSpec.Layers
  alias Skia.CommandSpec.Paths
  alias Skia.CommandSpec.Shapes
  alias Skia.CommandSpec.Text
  alias Skia.CommandSpec.Transforms

  @spec generated_targets() :: [{atom(), keyword()}]
  def generated_targets do
    [
      generated_atoms: [
        path: "native/skia_native/src/generated_atoms.rs",
        build: &generated_atoms/0
      ],
      generated_enums: [
        path: "native/skia_native/src/generated_enums.rs",
        build: &generated_enums/0
      ],
      generated_opts: [path: "native/skia_native/src/generated_opts.rs", build: &generated_opts/0],
      generated_opts_helpers: [
        path: "native/skia_native/src/generated_opts_helpers.rs",
        build: &generated_opts_helpers/0
      ],
      generated_resources: [
        path: "native/skia_native/src/generated_resources.rs",
        build: &generated_resources/0
      ],
      generated_layers: [
        path: "native/skia_native/src/generated_layers.rs",
        build: &generated_layers/0
      ],
      generated_transforms: [
        path: "native/skia_native/src/generated_transforms.rs",
        build: &generated_transforms/0
      ],
      generated_shapes: [
        path: "native/skia_native/src/generated_shapes.rs",
        build: &generated_shapes/0
      ],
      generated_text: [path: "native/skia_native/src/generated_text.rs", build: &generated_text/0],
      generated_images: [
        path: "native/skia_native/src/generated_images.rs",
        build: &generated_images/0
      ],
      generated_draw_paths: [
        path: "native/skia_native/src/generated_draw_paths.rs",
        build: &generated_draw_paths/0
      ],
      generated_clips: [
        path: "native/skia_native/src/generated_clips.rs",
        build: &generated_clips/0
      ],
      generated_paint: [
        path: "native/skia_native/src/generated_paint.rs",
        build: &generated_paint/0
      ],
      generated_path: [path: "native/skia_native/src/generated_path.rs", build: &generated_path/0],
      command_docs: [path: "docs/commands.md", build: &generated_docs/0]
    ]
  end

  @extra_enum_specs %{
    encoded_image_format: [skia: "SkEncodedImageFormat", rust: :EncodedImageFormat],
    blur_style: [skia: "SkBlurStyle", rust: :BlurStyle],
    sampling: [skia: "SkFilterMode", rust: :FilterMode],
    tile_mode: [skia: "SkTileMode", rust: :TileMode],
    mipmap_mode: [skia: "SkMipmapMode", rust: :MipmapMode]
  }

  @native_atoms [
    :ok,
    :error,
    :invalid_batch,
    :invalid_command,
    :invalid_path,
    :c,
    :p,
    :italic,
    :oblique,
    :invalid_image,
    :invalid_font,
    :invalid_picture,
    :invalid_text_blob,
    :invalid_runtime_effect,
    "nil",
    :render_failed,
    :unsupported_format,
    :png,
    :jpeg,
    :webp,
    :commands,
    :op,
    :args,
    :opts,
    :rgba,
    :linear_gradient,
    :radial_gradient,
    :sweep_gradient,
    :gradient_stop,
    :image_shader,
    :picture_shader,
    :runtime_effect_shader,
    :two_point_conical_gradient,
    :color_shader,
    :blur_filter,
    :compose_filter,
    :offset_filter,
    :drop_shadow_filter,
    :blur_mask_filter,
    :morphology_filter,
    :color_filter_image_filter,
    :shader_image_filter,
    :magnifier_filter,
    :matrix_convolution_filter,
    :matrix_transform_filter,
    :merge_filter,
    :tile_filter,
    :blend_color_filter,
    :matrix_color_filter,
    :compose_color_filter,
    :dilate,
    :erode,
    :dash_path_effect,
    :corner_path_effect,
    :compose_path_effect,
    :sum_path_effect,
    :trim_path_effect,
    :discrete_path_effect,
    :path_1d_effect,
    :line_2d_effect,
    :path_2d_effect,
    :translate,
    :morph,
    :normal,
    :inverted,
    :sampling_options,
    :sampling_cubic,
    :sampling_aniso,
    :mitchell,
    :catmull_rom,
    :matrix,
    :typeface,
    :triangle_strip,
    :triangle_fan,
    :left,
    :center,
    :right,
    :justify,
    :ltr,
    :rtl,
    :segments,
    :svg,
    :move_to,
    :line_to,
    :quad_to,
    :conic_to,
    :cubic_to,
    :r_move_to,
    :r_line_to,
    :r_quad_to,
    :r_conic_to,
    :r_cubic_to,
    :arc_to,
    :r_arc_to,
    :rrect,
    :cw,
    :ccw,
    :close
  ]

  @native_nifs [
    compile_runtime_effect: [
      args: [env: "Env<'a>", source: :String],
      returns: "NifResult<Term<'a>>",
      lifetime: :a
    ],
    render_png: [
      args: [env: "Env<'a>", batch: "Term<'a>"],
      returns: "NifResult<Term<'a>>",
      lifetime: :a
    ],
    render_rgba: [
      args: [env: "Env<'a>", batch: "Term<'a>"],
      returns: "NifResult<Term<'a>>",
      lifetime: :a
    ],
    render_compact_png: [
      args: [env: "Env<'a>", batch: "Term<'a>"],
      returns: "NifResult<Term<'a>>",
      lifetime: :a
    ],
    render_compact_rgba: [
      args: [env: "Env<'a>", batch: "Term<'a>"],
      returns: "NifResult<Term<'a>>",
      lifetime: :a
    ],
    render_jpeg: [
      args: [env: "Env<'a>", batch: "Term<'a>", quality: :u32],
      returns: "NifResult<Term<'a>>",
      lifetime: :a
    ],
    render_webp: [
      args: [env: "Env<'a>", batch: "Term<'a>", quality: :u32],
      returns: "NifResult<Term<'a>>",
      lifetime: :a
    ],
    decode_image: [
      args: [env: "Env<'a>", bytes: "Binary<'a>"],
      returns: "NifResult<Term<'a>>",
      lifetime: :a
    ],
    encode_image: [
      args: [env: "Env<'a>", image_term: "Term<'a>", format: :Atom, quality: :u32],
      returns: "NifResult<Term<'a>>",
      lifetime: :a
    ],
    resize_image: [
      args: [env: "Env<'a>", image_term: "Term<'a>", width: :i32, height: :i32],
      returns: "NifResult<Term<'a>>",
      lifetime: :a
    ],
    crop_image: [
      args: [env: "Env<'a>", image_term: "Term<'a>", source: "(f64, f64, f64, f64)"],
      returns: "NifResult<Term<'a>>",
      lifetime: :a
    ],
    load_font: [
      args: [env: "Env<'a>", bytes: "Binary<'a>"],
      returns: "NifResult<Term<'a>>",
      lifetime: :a
    ],
    font_families: [
      args: [env: "Env<'a>"],
      returns: "NifResult<Term<'a>>",
      lifetime: :a
    ],
    match_font: [
      args: [env: "Env<'a>", family: :String, weight: :i32, slant: :Atom],
      returns: "NifResult<Term<'a>>",
      lifetime: :a
    ],
    typeface_info: [
      args: [env: "Env<'a>", typeface_term: "Term<'a>"],
      returns: "NifResult<Term<'a>>",
      lifetime: :a
    ],
    font_metrics: [
      args: [env: "Env<'a>", font_term: "Term<'a>"],
      returns: "NifResult<Term<'a>>",
      lifetime: :a
    ],
    font_glyph_ids: [
      args: [env: "Env<'a>", font_term: "Term<'a>", text: :String],
      returns: "NifResult<Term<'a>>",
      lifetime: :a
    ],
    measure_text: [
      args: [env: "Env<'a>", text: :String, font_term: "Term<'a>", size: :f64],
      returns: "NifResult<Term<'a>>",
      lifetime: :a
    ],
    create_text_blob: [
      args: [env: "Env<'a>", text: :String, font_term: "Term<'a>", size: :f64],
      returns: "NifResult<Term<'a>>",
      lifetime: :a
    ],
    text_blob_bounds: [
      args: [env: "Env<'a>", blob_term: "Term<'a>"],
      returns: "NifResult<Term<'a>>",
      lifetime: :a
    ],
    record_picture: [
      args: [env: "Env<'a>", batch: "Term<'a>"],
      returns: "NifResult<Term<'a>>",
      lifetime: :a
    ],
    decode_picture: [
      args: [env: "Env<'a>", bytes: "Binary<'a>"],
      returns: "NifResult<Term<'a>>",
      lifetime: :a
    ],
    encode_picture: [
      args: [env: "Env<'a>", picture_term: "Term<'a>"],
      returns: "NifResult<Term<'a>>",
      lifetime: :a
    ],
    picture_info: [
      args: [env: "Env<'a>", picture_term: "Term<'a>"],
      returns: "NifResult<Term<'a>>",
      lifetime: :a
    ],
    path_to_svg: [
      args: [env: "Env<'a>", path_term: "Term<'a>"],
      returns: "NifResult<Term<'a>>",
      lifetime: :a
    ]
  ]

  @paint_enum_options [
    [name: :blend_mode, setter: :set_blend_mode, decoder: :decode_blend_mode]
  ]

  @stroke_enum_options [
    [name: :stroke_cap, setter: :set_stroke_cap, decoder: :decode_stroke_cap],
    [name: :stroke_join, setter: :set_stroke_join, decoder: :decode_stroke_join]
  ]

  @path_enum_options [
    [name: :fill_rule, setter: :set_fill_type, decoder: :decode_fill_rule]
  ]

  defp template_path(name) do
    __DIR__
    |> Path.join("../../priv/codegen/templates/#{name}")
    |> Path.expand()
  end

  @spec generated_native() :: String.t()
  def generated_native do
    functions =
      @native_nifs
      |> Enum.map_join("\n", fn {name, spec} ->
        args =
          spec
          |> Keyword.fetch!(:args)
          |> Keyword.keys()
          |> Enum.reject(&(&1 == :env))
          |> elixir_nif_args()

        if args == "" do
          "  def #{name}, do: :erlang.nif_error(:nif_not_loaded)"
        else
          "  def #{name}(#{args}), do: :erlang.nif_error(:nif_not_loaded)"
        end
      end)

    """
    # Generated by mix skia.codegen. Do not edit by hand.

    defmodule Skia.Native do
      @moduledoc false

      version = Mix.Project.config()[:version]

      use RustlerPrecompiled,
        otp_app: :skia,
        crate: "skia_native",
        base_url: "https://github.com/dannote/skia_ex/releases/download/v\#{version}",
        force_build: System.get_env("SKIA_EX_BUILD") in ["1", "true"],
        targets: ~w(
          aarch64-apple-darwin
          x86_64-apple-darwin
          x86_64-unknown-linux-gnu
        ),
        version: version

    #{functions}
    end
    """
  end

  defp elixir_nif_args(args), do: Enum.map_join(args, ", ", &"_#{elixir_arg_name(&1)}")

  defp elixir_arg_name(:env), do: :env
  defp elixir_arg_name(:image_term), do: :image
  defp elixir_arg_name(:font_term), do: :font
  defp elixir_arg_name(:typeface_term), do: :typeface
  defp elixir_arg_name(:picture_term), do: :picture
  defp elixir_arg_name(name), do: name

  @doc false
  @spec native_nif_specs() :: keyword(keyword())
  def native_nif_specs, do: @native_nifs

  @spec generated_native_nifs() :: String.t()
  def generated_native_nifs do
    wrappers =
      native_nif_specs()
      |> Enum.map(fn {name, spec} -> {name, Keyword.put(spec, :schedule, :dirty_cpu)} end)
      |> RustQ.Rustler.nif_exports()

    "generated_nifs.rs"
    |> template_path()
    |> RustQ.render_file!(preamble: generated_rust_preamble(), splice: [items: wrappers])
  end

  @spec generated_atoms() :: String.t()
  def generated_atoms do
    atoms =
      Skia.CommandSpec.all()
      |> Enum.flat_map(fn {name, spec} ->
        option_atoms = spec |> Keyword.get(:opts, []) |> Enum.map(&Keyword.fetch!(&1, :name))
        arg_atoms = spec |> Keyword.get(:args, []) |> Keyword.keys()
        [name, Keyword.get(spec, :op) | option_atoms ++ arg_atoms]
      end)
      |> Kernel.++(@native_atoms)
      |> Kernel.++(enum_atoms())
      |> Enum.reject(&is_nil/1)
      |> Enum.map(&to_string/1)
      |> Enum.uniq()
      |> Enum.sort()

    "generated_atoms.rs"
    |> template_path()
    |> RustQ.render_file!(
      preamble: generated_rust_preamble(),
      splice: [atoms: RustQ.Rustler.atoms(atoms, module: false)]
    )
  end

  @spec generated_enums() :: String.t()
  def generated_enums do
    entries =
      enum_defs()
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.map(fn {name, spec} ->
        values = spec |> Keyword.fetch!(:variants) |> Enum.map(&elem(&1, 0))

        Rust.const(enum_const_name(name), {:raw, "&[&str]"}, Rust.expr(enum_values(values)),
          vis: :pub
        )
      end)

    decoders =
      enum_defs()
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.map(fn {name, spec} -> enum_decoder(name, spec) end)

    "generated_enums.rs"
    |> template_path()
    |> RustQ.render_file!(
      preamble: generated_rust_preamble(),
      splice: [entries: entries, decoders: decoders]
    )
  end

  defp generated_rust_preamble do
    "// Generated by mix skia.codegen. Do not edit by hand.\n\n"
  end

  defp render_items(items, file) do
    "__rq_items!();"
    |> RustQ.render!(file, preamble: generated_rust_preamble(), splice: [items: items])
  end

  defp render_rustq_item(ast),
    do: ast |> RustQ.Rust.AST.Render.render_item() |> Rust.item()

  defp enum_atoms do
    enum_defs()
    |> Enum.flat_map(fn {_name, spec} ->
      spec |> Keyword.fetch!(:variants) |> Enum.map(&elem(&1, 0))
    end)
  end

  defp enum_defs do
    specs =
      Skia.CommandSpec.all()
      |> Enum.flat_map(fn {_name, spec} -> Keyword.get(spec, :opts, []) end)
      |> Enum.flat_map(fn opt -> opt |> Keyword.fetch!(:type) |> enum_type_spec() end)
      |> Kernel.++(Map.to_list(@extra_enum_specs))

    specs
    |> Enum.uniq_by(&elem(&1, 0))
    |> Map.new(fn {name, spec} ->
      variants =
        spec
        |> Keyword.fetch!(:skia)
        |> SkiaSafe.enum_variants()

      {name, Keyword.put(spec, :variants, variants)}
    end)
  end

  defp enum_type_spec({:enum, name, opts}), do: [{name, opts}]
  defp enum_type_spec(_type), do: []

  defp enum_const_name(name) do
    rust_name = name |> Atom.to_string() |> Macro.camelize()
    "#{Macro.underscore(rust_name) |> String.upcase()}S"
  end

  defp enum_values(values) do
    values = Enum.map_join(values, ", ", &inspect(to_string(&1)))
    "&[#{values}]"
  end

  defp enum_decoder(name, spec) do
    type = Keyword.fetch!(spec, :rust)

    cases =
      spec
      |> Keyword.fetch!(:variants)
      |> Enum.map(fn {atom, variant} -> {atom, "#{Rust.type(type)}::#{variant}"} end)

    RustQ.Rustler.atom_decoder("decode_#{name}", returns: type, cases: cases)
  end

  @spec generated_dispatch() :: String.t()
  def generated_dispatch do
    cases =
      Skia.CommandSpec.all()
      |> Enum.flat_map(fn {name, spec} ->
        case Keyword.fetch(spec, :handler) do
          {:ok, handler} -> [{Keyword.get(spec, :op, name), "#{handler}(canvas, command)"}]
          :error -> []
        end
      end)
      |> Enum.uniq()
      |> Enum.sort()

    case_lines =
      Enum.map_join(cases, "\n", fn {atom, call} ->
        "        value if value == atoms::#{atom}() => #{call},"
      end)

    compact_cases =
      compact_ops()
      |> Enum.map_join("\n", fn {atom, id} -> "        #{id} => Ok(atoms::#{atom}())," end)

    items = [
      Rust.item("""
      fn draw_command(canvas: &skia_safe::Canvas, command: Term) -> NifResult<()> {
          let value = command.map_get(atoms::op())?.decode::<Atom>()?;
          match value {
      #{case_lines}
              _ => Err(rustler::Error::BadArg),
          }
      }
      """),
      Rust.item("""
      fn compact_op_atom(id: i64) -> NifResult<Atom> {
          match id {
      #{compact_cases}
              _ => Err(rustler::Error::BadArg),
          }
      }
      """)
    ]

    "generated_dispatch.rs"
    |> template_path()
    |> RustQ.render_file!(preamble: generated_rust_preamble(), splice: [items: items])
  end

  defp compact_ops do
    Skia.CommandSpec.all()
    |> Enum.flat_map(fn {name, spec} -> [name, Keyword.get(spec, :op, name)] end)
    |> Enum.uniq()
    |> Enum.with_index(1)
  end

  @spec generated_style_helpers() :: String.t()
  def generated_style_helpers do
    helpers = [
      enum_option_applicator(:apply_blend_mode, :paint, "&mut Paint", @paint_enum_options),
      paint_effects_applicator(),
      clip_op_decoder(),
      stroke_options_applicator(),
      enum_option_applicator(:apply_fill_rule, :path, "&mut skia_safe::Path", @path_enum_options)
    ]

    "generated_style_helpers.rs"
    |> template_path()
    |> RustQ.render_file!(preamble: generated_rust_preamble(), splice: [items: helpers])
  end

  defp enum_option_applicator(:apply_blend_mode = name, target_name, target_type, options) do
    "enum_option_applicator.rs"
    |> template_path()
    |> RustQ.render_file!(
      bind: [function: name],
      splice: [
        args: [Rust.arg(target_name, target_type), Rust.arg(:opts, "&[(Atom, Term<'a>)]")],
        options:
          enum_option_lines(target_name, options) ++
            [Rust.stmt("apply_paint_effects(paint, opts)?;")]
      ]
    )
    |> Rust.item()
  end

  defp enum_option_applicator(name, target_name, target_type, options) do
    "enum_option_applicator.rs"
    |> template_path()
    |> RustQ.render_file!(
      bind: [function: name],
      splice: [
        args: [Rust.arg(target_name, target_type), Rust.arg(:opts, "&[(Atom, Term<'a>)]")],
        options: enum_option_lines(target_name, options)
      ]
    )
    |> Rust.item()
  end

  defp paint_effects_applicator do
    Rust.item("""
    fn apply_paint_effects<'a>(paint: &mut Paint, opts: &[(Atom, Term<'a>)]) -> NifResult<()> {
        if let Some(term) = opt_term(opts, atoms::image_filter()) {
            paint.set_image_filter(decode_image_filter(term)?);
        }
        if let Some(term) = opt_term(opts, atoms::path_effect()) {
            paint.set_path_effect(decode_path_effect(term)?);
        }
        if let Some(term) = opt_term(opts, atoms::color_filter()) {
            paint.set_color_filter(decode_color_filter(term)?);
        }
        if let Some(term) = opt_term(opts, atoms::mask_filter()) {
            paint.set_mask_filter(decode_mask_filter(term)?);
        }
        Ok(())
    }
    """)
  end

  defp clip_op_decoder do
    Rust.item("""
    fn decode_clip_op(value: Atom) -> NifResult<Option<ClipOp>> {
        Ok(Some(generated_enums::decode_clip_op(value)?))
    }
    """)
  end

  defp stroke_options_applicator do
    "stroke_options_applicator.rs"
    |> template_path()
    |> RustQ.render_file!(splice: [options: enum_option_lines(:paint, @stroke_enum_options)])
    |> Rust.item()
  end

  defp enum_option_lines(target_name, options) do
    Enum.map(options, fn option ->
      name = Keyword.fetch!(option, :name)
      setter = Keyword.fetch!(option, :setter)
      decoder = Keyword.fetch!(option, :decoder)

      Rust.stmt(
        "if let Some(term) = opt_term(opts, atoms::#{name}()) { #{target_name}.#{setter}(generated_enums::#{decoder}(term.decode::<Atom>()?)?); }"
      )
    end)
  end

  @spec generated_handlers() :: String.t()
  def generated_handlers do
    command_handlers =
      Skia.Codegen.GeneratedCommands.__rustq_asts__()
      |> Enum.reject(&String.ends_with?(Atom.to_string(&1.name), "_impl"))
      |> Enum.map(&render_rustq_item/1)

    handlers =
      command_handlers ++
        (Skia.Codegen.GeneratedHandlers.__rustq_asts__() |> Enum.map(&render_rustq_item/1))

    "generated_handlers.rs"
    |> template_path()
    |> RustQ.render_file!(
      preamble: generated_rust_preamble() <> "use skia_safe::Canvas;\n\n",
      splice: [items: handlers]
    )
  end

  defp append_if(values, false, _value), do: values
  defp append_if(values, _condition, value), do: values ++ [value]

  @spec generated_opts_helpers() :: String.t()
  def generated_opts_helpers do
    RustQ.Rustler.opts_helpers()
    |> render_items("generated_opts_helpers.rs")
  end

  @doc false
  @spec resource_specs() :: [{atom(), keyword()}]
  def resource_specs do
    [
      EncodedImage: [fields: [image: "Image"], decoder: :decode_encoded_image_ref],
      EncodedFont: [fields: [typeface: "skia_safe::Typeface"], decoder: :decode_encoded_font_ref],
      EncodedPicture: [
        fields: [bytes: "Vec<u8>", picture: "Picture"],
        decoder: :decode_encoded_picture_ref
      ],
      EncodedTextBlob: [fields: [blob: "TextBlob"], decoder: :decode_encoded_text_blob_ref],
      EncodedRuntimeEffect: [
        fields: [source: "String"],
        decoder: :decode_encoded_runtime_effect_ref
      ]
    ]
  end

  @spec generated_resources() :: String.t()
  def generated_resources do
    resources =
      resource_specs()
      |> Enum.flat_map(fn {name, opts} -> RustQ.Rustler.resource_handle(name, opts) end)

    "generated_resources.rs"
    |> template_path()
    |> RustQ.render_file!(preamble: generated_rust_preamble(), splice: [items: resources])
  end

  @spec generated_layers() :: String.t()
  def generated_layers do
    command_impls =
      Skia.Codegen.GeneratedCommands.__rustq_asts__()
      |> Enum.filter(&String.ends_with?(Atom.to_string(&1.name), "_impl"))
      |> Enum.map(&render_rustq_item/1)

    defrust_items = command_impls ++ Skia.Codegen.GeneratedLayers.__rustq_items__()

    legacy_items =
      Layers.commands()
      |> Keyword.drop([:save, :restore])
      |> generated_body_impls(:layer)

    render_items(defrust_items ++ legacy_items, "generated_layers.rs")
  end

  @spec generated_transforms() :: String.t()
  def generated_transforms do
    defrust_items = Enum.map(generated_transform_impl_asts(), &render_rustq_item/1)

    legacy_items =
      Transforms.commands()
      |> Keyword.drop(TransformImpls.commands())
      |> generated_body_impls(:transform)

    render_items(defrust_items ++ legacy_items, "generated_transforms.rs")
  end

  @doc false
  @spec generated_transform_impl_asts() :: [AST.Function.t()]
  def generated_transform_impl_asts, do: TransformImpls.generated_asts()

  @spec generated_shapes() :: String.t()
  def generated_shapes do
    defrust_items = Enum.map(generated_shape_impl_asts(), &render_rustq_item/1)

    legacy_items =
      Shapes.commands()
      |> Keyword.drop(ShapeImpls.commands())
      |> generated_body_impls(:shape_draw)

    render_items(defrust_items ++ legacy_items, "generated_shapes.rs")
  end

  @doc false
  @spec generated_shape_impl_asts() :: [AST.Function.t()]
  def generated_shape_impl_asts, do: ShapeImpls.generated_asts()

  @spec generated_text() :: String.t()
  def generated_text do
    items = generated_body_impls(Text.commands(), :text_draw) ++ text_helper_impls()
    render_items(items, "generated_text.rs")
  end

  @spec generated_images() :: String.t()
  def generated_images do
    Images.commands()
    |> generated_body_impls(:image_draw)
    |> render_items("generated_images.rs")
  end

  @spec generated_draw_paths() :: String.t()
  def generated_draw_paths do
    Paths.commands()
    |> generated_body_impls(:path_draw)
    |> render_items("generated_draw_paths.rs")
  end

  defp generated_body_impls(commands, key) do
    commands
    |> Enum.filter(fn {_name, spec} -> Keyword.has_key?(spec, key) end)
    |> Enum.map(fn {name, spec} -> body_impl(name, spec, key) end)
  end

  defp body_impl(name, spec, key) do
    handler = Keyword.fetch!(spec, :handler)
    command_body = Keyword.fetch!(spec, key)
    setup = command_body |> Keyword.get(:setup, []) |> rust_lines()
    body = command_body |> command_body_lines() |> rust_lines()
    setup = if setup == "", do: "", else: setup <> "\n\n    "
    params = body_impl_params(name, spec, setup <> body)
    lifetime = if Enum.any?(params, &String.contains?(&1, "'a")), do: "<'a>", else: ""
    params = Enum.join(params, ",\n    ")

    Rust.item("""
    fn #{handler}_impl#{lifetime}(
        #{params},
    ) -> NifResult<()> {
        #{setup}#{body}
        Ok(())
    }
    """)
  end

  defp command_body_lines(command_body) do
    cond do
      Keyword.has_key?(command_body, :body) -> Keyword.fetch!(command_body, :body)
      Keyword.has_key?(command_body, :call) -> [Keyword.fetch!(command_body, :call)]
    end
  end

  defp rust_lines(lines), do: Enum.map_join(lines, "\n    ", &rust_line/1)
  defp rust_line(line), do: line |> rust_fragment() |> Rust.to_fragment()

  defp rust_fragments(lines), do: Enum.map(lines, &rust_fragment/1)

  defp rust_fragment(line) when is_binary(line), do: Rust.raw(line)
  defp rust_fragment({:stmt, expr}), do: Rust.raw([rust_expr(expr), ";"])
  defp rust_fragment({:let, pattern, expr}), do: Rust.let_(pattern, rust_expr(expr))
  defp rust_fragment({:let_mut, pattern, expr}), do: Rust.let_mut(pattern, rust_expr(expr))
  defp rust_fragment({:assign, target, expr}), do: Rust.assign(target, rust_expr(expr))

  defp rust_fragment({:call, receiver, method, args}),
    do: Rust.call_stmt(receiver, method, rust_args(args))

  defp rust_fragment({:return_if, condition}), do: Rust.return_if(rust_expr(condition))

  defp rust_fragment({:if, condition, then_lines}),
    do: Rust.if_(rust_expr(condition), rust_fragments(then_lines))

  defp rust_fragment({:if_else, condition, then_lines, else_lines}) do
    Rust.if_(rust_expr(condition), rust_fragments(then_lines), else: rust_fragments(else_lines))
  end

  defp rust_fragment({:if_let, pattern, expr, then_lines}) do
    Rust.if_let(pattern, rust_expr(expr), rust_fragments(then_lines))
  end

  defp rust_fragment({:if_let_else, pattern, expr, then_lines, else_lines}) do
    Rust.if_let(pattern, rust_expr(expr), rust_fragments(then_lines),
      else: rust_fragments(else_lines)
    )
  end

  defp rust_fragment({:match, expr, clauses}) do
    arms = Enum.map(clauses, fn {pattern, lines} -> {pattern, rust_fragments(lines)} end)
    Rust.match_(rust_expr(expr), arms)
  end

  defp rust_args(args), do: Enum.map(args, &rust_expr/1)
  defp rust_expr(expr) when is_binary(expr), do: expr

  defp rust_expr({:call_expr, receiver, method, args}),
    do: Rust.call_expr(receiver, method, rust_args(args)) |> Rust.to_fragment()

  defp rust_expr({:some, value}), do: Rust.some(rust_expr(value)) |> Rust.to_fragment()
  defp rust_expr(:none), do: Rust.none() |> Rust.to_fragment()
  defp rust_expr({:tuple, values}), do: Rust.tuple(rust_args(values)) |> Rust.to_fragment()

  defp rust_expr({:cast, value, type}),
    do: Rust.cast(rust_expr(value), type) |> Rust.to_fragment()

  defp rust_expr({:question, value}), do: Rust.question(rust_expr(value)) |> Rust.to_fragment()
  defp rust_expr({:ref, value}), do: Rust.ref_expr(rust_expr(value)) |> Rust.to_fragment()

  defp rust_expr({:ref_mut, value}),
    do: Rust.ref_expr(rust_expr(value), mut: true) |> Rust.to_fragment()

  defp body_impl_params(name, spec, source) do
    opts = Keyword.get(spec, :opts, [])

    ["canvas: &skia_safe::Canvas"]
    |> append_if(Keyword.get(spec, :args, []) != [], "args: Vec<Term<'a>>")
    |> append_if(opts != [], "opts: generated_opts::#{opts_type(name)}<'a>")
    |> append_if(opts != [], "#{raw_opts_name(source)}: &[(Atom, Term<'a>)]")
  end

  defp opts_type(name), do: name |> Atom.to_string() |> Macro.camelize() |> Kernel.<>("Opts")

  defp raw_opts_name(source),
    do: if(String.contains?(source, "raw_opts"), do: "raw_opts", else: "_raw_opts")

  defp text_helper_impls do
    [
      Rust.item("""
      fn draw_paragraph_text<'a>(
          canvas: &skia_safe::Canvas,
          text: &str,
          x: f32,
          y: f32,
          width: f32,
          size: f32,
          paint: &Paint,
          opts: &generated_opts::TextOpts<'a>,
      ) -> NifResult<()> {
          let mut text_style = TextStyle::new();
          text_style.set_font_size(size);
          text_style.set_color(paint.color());
          if let Some(ref family) = opts.font_family {
              text_style.set_font_families(&[family]);
          }
          if let Some(line_height) = opts.line_height {
              text_style.set_height(line_height / size);
              text_style.set_height_override(true);
          }

          let mut paragraph_style = ParagraphStyle::new();
          paragraph_style.set_text_style(&text_style);
          if let Some(align) = opts.align {
              paragraph_style.set_text_align(decode_text_align(align)?);
          }
          if let Some(direction) = opts.direction {
              paragraph_style.set_text_direction(decode_text_direction(direction)?);
          }

          let mut font_collection = FontCollection::new();
          font_collection.set_default_font_manager(FontMgr::default(), None);
          let mut paragraph_builder = ParagraphBuilder::new(&paragraph_style, font_collection);
          if let Some(spans_term) = opts.spans {
              for (span_text, style_opts) in spans_term.decode::<Vec<(String, Vec<(Atom, Term)>)>>()? {
                  let span_style = text_style_from_opts(&text_style, &style_opts)?;
                  paragraph_builder.push_style(&span_style);
                  paragraph_builder.add_text(span_text);
                  paragraph_builder.pop();
              }
          } else {
              paragraph_builder.push_style(&text_style);
              paragraph_builder.add_text(text);
              paragraph_builder.pop();
          }
          let mut paragraph = paragraph_builder.build();
          paragraph.layout(width);
          paragraph.paint(canvas, Point::new(x, y));
          Ok(())
      }
      """),
      Rust.item("""
      fn text_style_from_opts<'a>(base: &TextStyle, opts: &[(Atom, Term<'a>)]) -> NifResult<TextStyle> {
          let mut style = base.clone();
          if let Some(size) = opt_f32_option(opts, atoms::size())? {
              style.set_font_size(size);
          }
          if let Some(fill) = opt_term(opts, atoms::fill()) {
              style.set_color(decode_color(fill)?);
          }
          if let Some(ref family) = opt_term(opts, atoms::font_family()).map(|term| term.decode::<String>()).transpose()? {
              style.set_font_families(&[family]);
          }
          if let Some(line_height) = opt_f32_option(opts, atoms::line_height())? {
              let font_size = opt_f32_option(opts, atoms::size())?.unwrap_or(base.font_size());
              style.set_height(line_height / font_size);
              style.set_height_override(true);
          }
          Ok(style)
      }
      """),
      Rust.item("""
      fn decode_text_align(value: Atom) -> NifResult<TextAlign> {
          if value == atoms::center() {
              Ok(TextAlign::Center)
          } else if value == atoms::right() {
              Ok(TextAlign::Right)
          } else if value == atoms::justify() {
              Ok(TextAlign::Justify)
          } else if value == atoms::left() {
              Ok(TextAlign::Left)
          } else {
              Err(rustler::Error::BadArg)
          }
      }
      """),
      Rust.item("""
      fn decode_text_direction(value: Atom) -> NifResult<TextDirection> {
          if value == atoms::rtl() {
              Ok(TextDirection::RTL)
          } else if value == atoms::ltr() {
              Ok(TextDirection::LTR)
          } else {
              Err(rustler::Error::BadArg)
          }
      }
      """)
    ]
  end

  @spec generated_clips() :: String.t()
  def generated_clips do
    Clips.commands()
    |> generated_body_impls(:clip)
    |> render_items("generated_clips.rs")
  end

  @spec generated_paint() :: String.t()
  def generated_paint do
    "generated_paint.rs"
    |> template_path()
    |> RustQ.render_file!(preamble: generated_rust_preamble())
  end

  @spec generated_path() :: String.t()
  def generated_path do
    "generated_path.rs"
    |> template_path()
    |> RustQ.render_file!(preamble: generated_rust_preamble())
  end

  @spec generated_opts() :: String.t()
  def generated_opts do
    commands =
      Skia.CommandSpec.all()
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

    "generated_opts.rs"
    |> template_path()
    |> RustQ.render_file!(preamble: generated_rust_preamble(), splice: [commands: commands])
  end

  @spec generated_docs() :: String.t()
  def generated_docs do
    rows =
      Skia.CommandSpec.all()
      |> Enum.map_join("\n", fn {name, spec} ->
        args = spec |> Keyword.get(:args, []) |> format_args()
        opts = spec |> Keyword.get(:opts, []) |> format_opts()
        defaults = spec |> Keyword.get(:defaults, []) |> format_defaults()
        native = name |> native_refs() |> format_native_refs()
        "| `#{name}` | #{args} | #{opts} | #{defaults} | #{native} |"
      end)

    enums =
      enum_defs()
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.map_join("\n", fn {name, spec} ->
        values =
          spec
          |> Keyword.fetch!(:variants)
          |> Enum.map(&elem(&1, 0))
          |> Enum.map_join(", ", &"`:#{&1}`")

        "- `#{name}`: #{values}"
      end)

    rust_docs = generated_rust_doc_section()

    IO.iodata_to_binary([
      "<!-- Generated by mix skia.codegen. Do not edit by hand. -->\n\n",
      "# Skia command reference\n\n",
      "| Command | Args | Options | Defaults | Native references |\n",
      "| --- | --- | --- | --- | --- |\n",
      rows,
      "\n\n## Enums\n\n",
      enums,
      "\n\n",
      rust_docs,
      "\n"
    ])
  end

  defp opts_decoder_field(opt) do
    {Keyword.fetch!(opt, :name), [type: rust_option_type(opt), decode: option_decoder(opt)]}
  end

  defp rust_option_type(opt) do
    type = Keyword.fetch!(opt, :type)

    if Keyword.get(opt, :required, false) do
      rust_required_type(type)
    else
      rust_optional_type(type)
    end
  end

  defp rust_required_type(:number), do: "f32"
  defp rust_required_type(:boolean), do: "bool"
  defp rust_required_type(:atom), do: "Atom"
  defp rust_required_type({:enum, _name, _opts}), do: "Atom"
  defp rust_required_type(:integer), do: "i64"
  defp rust_required_type(:string), do: "String"

  defp rust_required_type(type)
       when type in [
              :color,
              :path,
              :image,
              :font,
              :text_blob,
              :vertices,
              :image_filter,
              :color_filter,
              :mask_filter,
              :path_effect,
              :sampling_options,
              :paint,
              :term
            ],
       do: "Term<'a>"

  defp rust_required_type({:tuple, _types}), do: "Term<'a>"

  defp rust_optional_type(:number), do: "Option<f32>"
  defp rust_optional_type(:boolean), do: "Option<bool>"
  defp rust_optional_type(:atom), do: "Option<Atom>"
  defp rust_optional_type({:enum, _name, _opts}), do: "Option<Atom>"
  defp rust_optional_type(:integer), do: "Option<i64>"
  defp rust_optional_type(:string), do: "Option<String>"

  defp rust_optional_type(type)
       when type in [
              :color,
              :path,
              :image,
              :font,
              :text_blob,
              :vertices,
              :image_filter,
              :color_filter,
              :mask_filter,
              :path_effect,
              :sampling_options,
              :paint,
              :term
            ],
       do: "Option<Term<'a>>"

  defp rust_optional_type({:tuple, _types}), do: "Option<Term<'a>>"

  defp option_decoder(opt) do
    name = Keyword.fetch!(opt, :name)
    type = Keyword.fetch!(opt, :type)

    if Keyword.get(opt, :required, false) do
      required_decoder(type, name)
    else
      optional_decoder(type, name)
    end
  end

  defp required_decoder(:number, name), do: R.opt_decode(:opt_f32, :opts, name)

  defp required_decoder(:boolean, name),
    do: R.required_opt_decode(:opt_bool_option, :opts, name)

  defp required_decoder(:atom, name),
    do: R.required_opt_decode(:opt_atom_option, :opts, name)

  defp required_decoder({:enum, _name, _opts}, name),
    do: R.required_opt_decode(:opt_atom_option, :opts, name)

  defp required_decoder(:integer, name),
    do: R.required_term_decode(:opts, name, :i64)

  defp required_decoder(:string, name),
    do: R.required_term_decode(:opts, name, :String)

  defp required_decoder(type, name)
       when type in [
              :color,
              :path,
              :image,
              :font,
              :text_blob,
              :vertices,
              :image_filter,
              :color_filter,
              :mask_filter,
              :path_effect,
              :sampling_options,
              :paint,
              :term
            ],
       do: R.required_term(:opts, name)

  defp required_decoder({:tuple, _types}, name), do: R.required_term(:opts, name)

  defp optional_decoder(:number, name), do: R.opt_decode(:opt_f32_option, :opts, name)
  defp optional_decoder(:boolean, name), do: R.opt_decode(:opt_bool_option, :opts, name)
  defp optional_decoder(:atom, name), do: R.opt_decode(:opt_atom_option, :opts, name)

  defp optional_decoder({:enum, _name, _opts}, name),
    do: R.opt_decode(:opt_atom_option, :opts, name)

  defp optional_decoder(:integer, name), do: R.optional_term_decode(:opts, name, :i64)
  defp optional_decoder(:string, name), do: R.optional_term_decode(:opts, name, :String)

  defp optional_decoder(type, name)
       when type in [
              :color,
              :path,
              :image,
              :font,
              :text_blob,
              :vertices,
              :image_filter,
              :color_filter,
              :mask_filter,
              :path_effect,
              :sampling_options,
              :paint,
              :term
            ],
       do: A.call(:opt_term, [:opts, A.atom(name)])

  defp optional_decoder({:tuple, _types}, name), do: A.call(:opt_term, [:opts, A.atom(name)])

  defp format_args([]), do: "—"

  defp format_args(args) do
    args
    |> Enum.map_join("<br>", fn {name, type} -> "`#{name}: #{format_type(type)}`" end)
  end

  defp format_opts([]), do: "—"

  defp format_opts(opts) do
    opts
    |> Enum.map_join("<br>", fn opt ->
      name = Keyword.fetch!(opt, :name)
      type = opt |> Keyword.fetch!(:type) |> format_type()
      required = if Keyword.get(opt, :required, false), do: " required", else: ""
      "`#{name}: #{type}`#{required}"
    end)
  end

  defp format_defaults([]), do: "—"

  defp format_defaults(defaults) do
    defaults
    |> Enum.map_join("<br>", fn {name, value} -> "`#{name}: #{inspect(value)}`" end)
  end

  defp native_refs(command) do
    command
    |> Skia.CommandSpec.fetch!()
    |> Keyword.get(:native_refs, [])
    |> Enum.filter(&SkiaSafe.native_ref_exists?/1)
  end

  defp format_native_refs([]), do: "—"

  defp format_native_refs(refs) do
    refs
    |> Enum.map_join("<br>", &"`#{&1}`")
  end

  defp generated_rust_doc_section do
    docs =
      Skia.CommandSpec.all()
      |> Enum.flat_map(fn {_name, spec} -> Keyword.get(spec, :native_refs, []) end)
      |> Enum.filter(&SkiaSafe.native_ref_exists?/1)
      |> Enum.uniq()
      |> Enum.sort()
      |> Enum.flat_map(&rust_doc_entry/1)

    if docs == [] do
      "## Rust doc excerpts\n\nNo local `skia-safe` source docs found.\n"
    else
      IO.iodata_to_binary(["## Rust doc excerpts\n\n", Enum.join(docs, "\n\n")])
    end
  end

  defp rust_doc_entry(ref) do
    case SkiaSafe.rust_doc_snippet(ref) do
      nil -> []
      snippet -> ["### `#{ref}`\n\n#{snippet}"]
    end
  end

  defp format_type({:enum, name, _opts}), do: name

  defp format_type({:tuple, types}) do
    inner = Enum.map_join(types, ", ", &format_type/1)
    "{#{inner}}"
  end

  defp format_type(type), do: to_string(type)
end
