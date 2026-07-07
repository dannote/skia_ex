defmodule Skia.Codegen.Rust.Targets do
  @moduledoc false

  @spec all() :: [{atom(), keyword()}]
  def all do
    [
      generated_atoms: [
        path: "native/skia_native/src/generated_atoms.rs",
        build: fn -> apply(Skia.Codegen, :generated_atoms, []) end
      ],
      generated_enums: [
        path: "native/skia_native/src/generated_enums.rs",
        build: fn -> apply(Skia.Codegen, :generated_enums, []) end
      ],
      generated_opts: [
        path: "native/skia_native/src/generated_opts.rs",
        build: fn -> apply(Skia.Codegen, :generated_opts, []) end
      ],
      generated_opts_helpers: [
        path: "native/skia_native/src/generated_opts_helpers.rs",
        build: fn -> apply(Skia.Codegen, :generated_opts_helpers, []) end
      ],
      generated_resources: [
        path: "native/skia_native/src/generated_resources.rs",
        build: fn -> apply(Skia.Codegen, :generated_resources, []) end
      ],
      generated_layers: [
        path: "native/skia_native/src/generated_layers.rs",
        build: fn -> apply(Skia.Codegen, :generated_layers, []) end
      ],
      generated_transforms: [
        path: "native/skia_native/src/generated_transforms.rs",
        build: fn -> apply(Skia.Codegen, :generated_transforms, []) end
      ],
      generated_shapes: [
        path: "native/skia_native/src/generated_shapes.rs",
        build: fn -> apply(Skia.Codegen, :generated_shapes, []) end
      ],
      generated_text: [
        path: "native/skia_native/src/generated_text.rs",
        build: fn -> apply(Skia.Codegen, :generated_text, []) end
      ],
      generated_images: [
        path: "native/skia_native/src/generated_images.rs",
        build: fn -> apply(Skia.Codegen, :generated_images, []) end
      ],
      generated_draw_paths: [
        path: "native/skia_native/src/generated_draw_paths.rs",
        build: fn -> apply(Skia.Codegen, :generated_draw_paths, []) end
      ],
      generated_clips: [
        path: "native/skia_native/src/generated_clips.rs",
        build: fn -> apply(Skia.Codegen, :generated_clips, []) end
      ],
      generated_paint: [
        path: "native/skia_native/src/generated_paint.rs",
        build: fn -> apply(Skia.Codegen, :generated_paint, []) end
      ],
      generated_path: [
        path: "native/skia_native/src/generated_path.rs",
        build: fn -> apply(Skia.Codegen, :generated_path, []) end
      ]
    ]
  end
end
