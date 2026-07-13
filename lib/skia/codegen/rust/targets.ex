defmodule Skia.Codegen.Rust.Targets do
  @moduledoc false

  alias Skia.Codegen.Rust.Commands
  alias Skia.Codegen.Rust.Core
  alias Skia.Codegen.Rust.Nifs
  alias Skia.Codegen.Rust.Opts

  @spec all() :: [{atom(), keyword()}]
  def all do
    [
      generated_atoms: [
        path: "native/skia_native/src/generated_atoms.rs",
        build: &Core.generated_atoms/0
      ],
      generated_enums: [
        path: "native/skia_native/src/generated_enums.rs",
        build: &Core.generated_enums/0
      ],
      generated_opts: [
        path: "native/skia_native/src/generated_opts.rs",
        build: &Opts.generated_opts/0
      ],
      generated_opts_helpers: [
        path: "native/skia_native/src/generated_opts_helpers.rs",
        build: &Core.generated_opts_helpers/0
      ],
      generated_resources: [
        path: "native/skia_native/src/generated_resources.rs",
        build: &Core.generated_resources/0
      ],
      generated_dispatch: [
        path: "native/skia_native/src/generated_dispatch.rs",
        build: &Core.generated_dispatch/0
      ],
      generated_style_helpers: [
        path: "native/skia_native/src/generated_style_helpers.rs",
        build: &Core.generated_style_helpers/0
      ],
      generated_layers: [
        path: "native/skia_native/src/generated_layers.rs",
        build: &Commands.generated_layers/0
      ],
      generated_transforms: [
        path: "native/skia_native/src/generated_transforms.rs",
        build: &Commands.generated_transforms/0
      ],
      generated_shapes: [
        path: "native/skia_native/src/generated_shapes.rs",
        build: &Commands.generated_shapes/0
      ],
      generated_text: [
        path: "native/skia_native/src/generated_text.rs",
        build: &Commands.generated_text/0
      ],
      generated_images: [
        path: "native/skia_native/src/generated_images.rs",
        build: &Commands.generated_images/0
      ],
      generated_draw_paths: [
        path: "native/skia_native/src/generated_draw_paths.rs",
        build: &Commands.generated_draw_paths/0
      ],
      generated_clips: [
        path: "native/skia_native/src/generated_clips.rs",
        build: &Commands.generated_clips/0
      ],
      generated_paint: [
        path: "native/skia_native/src/generated_paint.rs",
        build: &Commands.generated_paint/0
      ],
      generated_path: [
        path: "native/skia_native/src/generated_path.rs",
        build: &Commands.generated_path/0
      ],
      generated_nifs: [
        path: "native/skia_native/src/generated_nifs.rs",
        build: &Nifs.generated_native_nifs/0
      ],
      native_stubs: [
        path: "lib/skia/native/generated_stubs.ex",
        build: &Nifs.generated_native_stubs/0
      ]
    ]
  end
end
