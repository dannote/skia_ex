defmodule Skia.Codegen.ArchitectureTest do
  use ExUnit.Case, async: true

  test "legacy command specs are gone" do
    refute File.exists?("lib/skia/command_spec")
    refute File.exists?("lib/skia/command_spec.ex")
  end

  test "command metadata does not carry native_refs" do
    refute Enum.any?(Skia.Codegen.Commands.all(), fn {_name, spec} ->
             Keyword.has_key?(spec, :native_refs)
           end)
  end

  test "native schema uses Cargo and Syn instead of registry globs or regex Rust parsing" do
    source = File.read!("lib/skia/codegen/native_schema.ex")

    assert source =~ "RustQ.Cargo"
    assert source =~ "RustQ.Syn"
    refute source =~ "Regex"
    refute source =~ ".cargo/registry"
  end

  test "SkiaSafe enum lookup uses RustQ package indexes instead of registry globs" do
    source = File.read!("lib/skia/codegen/skia_safe.ex")

    assert source =~ "RustQ.NativeEnumDescriptor"
    assert source =~ "RustQ.Syn.Index.from_package"
    refute source =~ "RustQ.Cargo"
    refute source =~ ".cargo/registry"
  end

  test "atom generation is derived from code and Syn instead of a manual atom list" do
    source = File.read!("lib/skia/codegen.ex")

    refute source =~ "@native_atoms"
    assert source =~ "RustQ.Syn.atom_references!"
  end

  test "legacy generated command markdown is gone" do
    refute File.exists?("docs/commands.md")

    config = File.read!("rustq.exs")
    refute config =~ "command_docs"
    refute config =~ "generated_docs"
  end

  test "simple layer commands do not generate trivial impl wrappers" do
    source = File.read!("lib/skia/codegen/rusty/layers.ex")

    refute source =~ "draw_save_impl"
    refute source =~ "draw_restore_impl"
  end

  test "native overlays stay ergonomic and validate native methods" do
    assert Skia.Codegen.CommandOverlay.validate_native!() == :ok

    source = File.read!("lib/skia/codegen/command_overlay.ex")
    refute source =~ "opts:"
    refute source =~ "native_refs"
    refute source =~ "native_shape"
    refute source =~ ~s(native: {)
    assert source =~ "native: Canvas.draw_rect"
    assert source =~ "native: Canvas.clip_rect"
    assert source =~ "expands_to: [Canvas.clip_path"
  end

  test "codegen tests live under test/skia/codegen" do
    root_codegen_tests =
      "test/skia/*codegen*_test.exs"
      |> Path.wildcard()
      |> Enum.reject(&String.starts_with?(&1, "test/skia/codegen/"))

    assert root_codegen_tests == []
  end
end
