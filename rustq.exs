use RustQ.Config

require_file("lib/skia/codegen/skia_safe.ex")
require_file("lib/skia/codegen/native_schema.ex")
require_file("lib/skia/codegen/enums.ex")
require_file("lib/skia/codegen/command_specs.ex")
require_file("lib/skia/codegen/command_overlay/dsl.ex")
require_file("lib/skia/codegen/command_overlay.ex")
require_file("lib/skia/codegen/commands/shapes.ex")
require_file("lib/skia/codegen/commands/text.ex")
require_file("lib/skia/codegen/commands/images.ex")
require_file("lib/skia/codegen/commands/layers.ex")
require_file("lib/skia/codegen/commands/transforms.ex")
require_file("lib/skia/codegen/commands/paths.ex")
require_file("lib/skia/codegen/commands/clips.ex")
require_file("lib/skia/codegen/commands.ex")
require_file("lib/skia/codegen/rusty/args.ex")
require_file("lib/skia/codegen/rusty/domain.ex")
require_file("lib/skia/codegen/rusty/paint.ex")
require_file("lib/skia/codegen/rusty/skia_safe_sources.ex")
require_file("lib/skia/codegen/rusty/paint_support.ex")
require_file("lib/skia/codegen/rusty/style_helpers.ex")
require_file("lib/skia/codegen/rusty/clips.ex")
require_file("lib/skia/codegen/rusty/images.ex")
require_file("lib/skia/codegen/rusty/layers.ex")
require_file("lib/skia/codegen/rusty/paths.ex")
require_file("lib/skia/codegen/rusty/text.ex")
require_file("lib/skia/codegen/rusty/transforms.ex")
require_file("lib/skia/codegen/rusty/shapes.ex")
require_file("lib/skia/codegen.ex")

generate :native, "lib/skia/native.ex" do
  build(&Skia.Codegen.generated_native/0)
end

generate :generated_nifs, "native/skia_native/src/generated_nifs.rs" do
  build(&Skia.Codegen.generated_native_nifs/0)
end

generate :generated_atoms, "native/skia_native/src/generated_atoms.rs" do
  build(&Skia.Codegen.generated_atoms/0)
end

generate :generated_enums, "native/skia_native/src/generated_enums.rs" do
  build(&Skia.Codegen.generated_enums/0)
end

generate :generated_opts, "native/skia_native/src/generated_opts.rs" do
  build(&Skia.Codegen.generated_opts/0)
end

generate :generated_opts_helpers, "native/skia_native/src/generated_opts_helpers.rs" do
  build(&Skia.Codegen.generated_opts_helpers/0)
end

generate :generated_resources, "native/skia_native/src/generated_resources.rs" do
  build(&Skia.Codegen.generated_resources/0)
end

generate :generated_dispatch, "native/skia_native/src/generated_dispatch.rs" do
  build(&Skia.Codegen.generated_dispatch/0)
end

generate :generated_style_helpers, "native/skia_native/src/generated_style_helpers.rs" do
  build(&Skia.Codegen.generated_style_helpers/0)
end

generate :generated_layers, "native/skia_native/src/generated_layers.rs" do
  build(&Skia.Codegen.generated_layers/0)
end

generate :generated_transforms, "native/skia_native/src/generated_transforms.rs" do
  build(&Skia.Codegen.generated_transforms/0)
end

generate :generated_shapes, "native/skia_native/src/generated_shapes.rs" do
  build(&Skia.Codegen.generated_shapes/0)
end

generate :generated_text, "native/skia_native/src/generated_text.rs" do
  build(&Skia.Codegen.generated_text/0)
end

generate :generated_images, "native/skia_native/src/generated_images.rs" do
  build(&Skia.Codegen.generated_images/0)
end

generate :generated_draw_paths, "native/skia_native/src/generated_draw_paths.rs" do
  build(&Skia.Codegen.generated_draw_paths/0)
end

generate :generated_clips, "native/skia_native/src/generated_clips.rs" do
  build(&Skia.Codegen.generated_clips/0)
end

generate :generated_paint, "native/skia_native/src/generated_paint.rs" do
  build(&Skia.Codegen.generated_paint/0)
end

generate :generated_path, "native/skia_native/src/generated_path.rs" do
  build(&Skia.Codegen.generated_path/0)
end
