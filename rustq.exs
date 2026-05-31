import RustQ.Config

generate :generated_atoms, "native/skia_native/src/generated_atoms.rs" do
  build &Skia.Codegen.generated_atoms/0
end

generate :generated_enums, "native/skia_native/src/generated_enums.rs" do
  build &Skia.Codegen.generated_enums/0
end

generate :generated_opts, "native/skia_native/src/generated_opts.rs" do
  build &Skia.Codegen.generated_opts/0
end

generate :command_docs, "docs/commands.md" do
  build &Skia.Codegen.generated_docs/0
end
