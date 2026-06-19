defmodule Skia.Codegen.ArchitectureTest do
  use ExUnit.Case, async: true

  alias Skia.Codegen.CommandOverlay
  alias Skia.Codegen.Commands

  test "legacy command specs are gone" do
    refute File.exists?("lib/skia/command_spec")
    refute File.exists?("lib/skia/command_spec.ex")
  end

  test "command metadata does not carry native_refs" do
    refute Enum.any?(Commands.all(), fn {_name, spec} ->
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
    assert source =~ "Index.cached_package"
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

  test "standalone generated handler layer is gone" do
    refute File.exists?("lib/skia/codegen/handler_shells.ex")
    refute File.exists?("native/skia_native/src/generated_handlers.rs")
    refute File.exists?("priv/codegen/templates/generated_handlers.rs")
    refute File.exists?("priv/codegen/templates/handler_shell.rs")

    refute File.read!("rustq.exs") =~ "generated_handlers"
    refute File.read!("native/skia_native/src/lib.rs") =~ "generated_handlers.rs"

    source =
      "lib/skia/codegen/rusty/*.ex"
      |> Path.wildcard()
      |> Enum.map_join("\n", &File.read!/1)

    refute source =~ "defcommand_handler"
    assert source =~ "defmacro handlers"
  end

  test "Rusty command domains use clear from and commands options" do
    use_sites =
      "lib/skia/codegen/rusty/*.ex"
      |> Path.wildcard()
      |> Enum.reject(&String.ends_with?(&1, "/domain.ex"))
      |> Enum.map_join("\n", &File.read!/1)

    assert use_sites =~ "use Skia.Codegen.Rusty.Domain"
    assert use_sites =~ "from:"
    refute use_sites =~ "only:"
  end

  test "simple layer commands do not generate trivial impl wrappers" do
    source = File.read!("lib/skia/codegen/rusty/layers.ex")

    refute source =~ "draw_save_impl"
    refute source =~ "draw_restore_impl"
  end

  test "native overlays stay ergonomic and validate native methods" do
    assert CommandOverlay.validate_native!() == :ok

    source = File.read!("lib/skia/codegen/command_overlay.ex")
    refute source =~ "opts:"
    refute source =~ "native_refs"
    refute source =~ "native_shape"
    refute source =~ ~s(native: {)
    assert source =~ "native: Canvas.draw_rect"
    assert source =~ "native: Canvas.clip_rect"
    assert source =~ "expands_to: [Canvas.clip_path"
  end

  test "enum specs do not carry Rust path escape hatches" do
    source = File.read!("lib/skia/codegen/enums.ex")

    refute source =~ "rust:"
    assert source =~ "safe_enum_type!"
  end

  test "removed type and decoder boilerplate patterns do not return" do
    source =
      (Path.wildcard("lib/**/*.ex") ++ Path.wildcard("test/**/*.exs"))
      |> Enum.map_join("\n", &File.read!/1)

    forbidden = [
      "native" <> "_enum(",
      "from" <> "_spec_ast",
      "field" <> "_spec(",
      "required" <> "_decoder_for_kind",
      "optional" <> "_decoder_for_kind",
      "option" <> "_type_category",
      "String" <> ".split" <> "(rust_type",
      "String" <> ".split" <> "(" <> ~s("::"),
      "{:" <> "enum,"
    ]

    Enum.each(forbidden, &refute(source =~ &1))
  end

  test "codegen tests live under test/skia/codegen" do
    root_codegen_tests =
      "test/skia/*codegen*_test.exs"
      |> Path.wildcard()
      |> Enum.reject(&String.starts_with?(&1, "test/skia/codegen/"))

    assert root_codegen_tests == []
  end
end
