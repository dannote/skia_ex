defmodule Skia.Codegen do
  @moduledoc false

  alias RustQ.Rust
  alias RustQ.Rust.AST
  alias RustQ.Rust.AST.Builder, as: A
  alias RustQ.Rust.AST.PatternBuilder, as: P
  alias Skia.Codegen.Commands
  alias Skia.Codegen.Enums
  alias Skia.Codegen.Rusty

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
      generated_path: [path: "native/skia_native/src/generated_path.rs", build: &generated_path/0]
    ]
  end

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

    render_items(wrappers, "generated_nifs.rs")
  end

  @spec generated_atoms() :: String.t()
  def generated_atoms do
    atoms =
      Commands.all()
      |> Enum.flat_map(fn {name, spec} ->
        option_atoms = spec |> Keyword.get(:opts, []) |> Enum.map(&Keyword.fetch!(&1, :name))
        arg_atoms = spec |> Keyword.get(:args, []) |> Keyword.keys()
        [name, Keyword.get(spec, :op) | option_atoms ++ arg_atoms]
      end)
      |> Kernel.++(Enums.atoms())
      |> Kernel.++(rust_atom_references())
      |> Enum.reject(&is_nil/1)
      |> Enum.map(&to_string/1)
      |> Enum.uniq()
      |> Enum.sort()

    "__rq_atoms!();"
    |> RustQ.render!(
      "generated_atoms.rs",
      preamble: generated_rust_preamble(),
      splice: [atoms: RustQ.Rustler.atoms(atoms, module: false)]
    )
  end

  @spec generated_enums() :: String.t()
  def generated_enums, do: Enums.generated()

  defp rust_atom_references do
    "native/skia_native/src/*.rs"
    |> Path.wildcard()
    |> Enum.reject(&String.ends_with?(&1, "/generated_atoms.rs"))
    |> Enum.flat_map(fn path ->
      path
      |> File.read!()
      |> RustQ.Syn.atom_references!()
    end)
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

  defp rusty_asts(module), do: module.__rustq_asts__()

  @spec generated_dispatch() :: String.t()
  def generated_dispatch do
    cases =
      Commands.all()
      |> Enum.flat_map(fn {name, spec} ->
        case Keyword.fetch(spec, :handler) do
          {:ok, handler} -> [{Keyword.get(spec, :op, name), "#{handler}(canvas, command)"}]
          :error -> []
        end
      end)
      |> Enum.uniq()
      |> Enum.sort()

    dispatch =
      RustQ.Rustler.atom_dispatch(:draw_command,
        args: [canvas: "&skia_safe::Canvas", command: :Term],
        on: "command.map_get(atoms::op())?.decode::<Atom>()?",
        cases: cases,
        unknown: "Err(rustler::Error::BadArg)"
      )

    items = [dispatch, render_rustq_item(compact_op_atom_ast())]

    render_items(items, "generated_dispatch.rs")
  end

  defp compact_op_atom_ast do
    %AST.Function{
      name: :compact_op_atom,
      args: [A.arg(:id, :i64)],
      returns: "NifResult<Atom>",
      body: [
        A.return_stmt(
          A.match_expr(
            A.var(:id),
            Enum.map(compact_ops(), fn {atom, id} ->
              %AST.Arm{pattern: P.lit(id), body: [A.return_stmt(A.ok(A.atom(atom)))]}
            end) ++ [%AST.Arm{pattern: P.wildcard(), body: [A.return_stmt(A.err(A.badarg()))]}]
          )
        )
      ]
    }
  end

  defp compact_ops do
    Commands.all()
    |> Enum.flat_map(fn {name, spec} -> [name, Keyword.get(spec, :op, name)] end)
    |> Enum.uniq()
    |> Enum.with_index(1)
  end

  @spec generated_style_helpers() :: String.t()
  def generated_style_helpers do
    Rusty.StyleHelpers
    |> rusty_asts()
    |> Enum.map(&render_rustq_item/1)
    |> render_items("generated_style_helpers.rs")
  end

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

    render_items(resources, "generated_resources.rs")
  end

  @spec generated_layers() :: String.t()
  def generated_layers do
    items =
      (Rusty.Layers.generated_command_asts() ++ Rusty.Layers.generated_asts())
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
  def generated_transform_impl_asts, do: Rusty.Transforms.generated_asts()

  @spec generated_shapes() :: String.t()
  def generated_shapes do
    generated_shape_impl_asts()
    |> Enum.map(&render_rustq_item/1)
    |> render_items("generated_shapes.rs")
  end

  @doc false
  @spec generated_shape_impl_asts() :: [AST.Function.t()]
  def generated_shape_impl_asts, do: Rusty.Shapes.generated_asts()

  @spec generated_text() :: String.t()
  def generated_text do
    (Rusty.Text.generated_asts() ++ rusty_asts(Rusty.TextHelpers))
    |> Enum.map(&render_rustq_item/1)
    |> render_items("generated_text.rs")
  end

  @spec generated_images() :: String.t()
  def generated_images do
    Rusty.Images.generated_asts()
    |> Enum.map(&render_rustq_item/1)
    |> render_items("generated_images.rs")
  end

  @spec generated_draw_paths() :: String.t()
  def generated_draw_paths do
    Rusty.Paths.generated_asts()
    |> Enum.map(&render_rustq_item/1)
    |> render_items("generated_draw_paths.rs")
  end

  @spec generated_clips() :: String.t()
  def generated_clips do
    Rusty.Clips.generated_asts()
    |> Enum.map(&render_rustq_item/1)
    |> render_items("generated_clips.rs")
  end

  @spec generated_paint() :: String.t()
  def generated_paint do
    "paint_support.rs"
    |> template_path()
    |> RustQ.render_file!(preamble: generated_rust_preamble())
  end

  @spec generated_path() :: String.t()
  def generated_path do
    path_support = File.read!(template_path("path_support.rs"))

    ["__rq_items!();\n", path_support]
    |> IO.iodata_to_binary()
    |> RustQ.render!(
      "generated_path.rs",
      preamble: generated_rust_preamble(),
      splice: [items: Enum.map(rusty_asts(Rusty.PathSupport), &render_rustq_item/1)]
    )
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
