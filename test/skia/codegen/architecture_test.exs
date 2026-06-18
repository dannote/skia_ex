defmodule Skia.Codegen.ArchitectureTest do
  use ExUnit.Case, async: true

  test "legacy command specs are gone" do
    refute File.exists?("lib/skia/command_spec")
    refute File.exists?("lib/skia/command_spec.ex")
  end

  test "command metadata does not carry native_refs" do
    refute codegen_source() =~ "native_refs"
  end

  test "native schema uses Cargo and Syn instead of registry globs or regex Rust parsing" do
    source = File.read!("lib/skia/codegen/native_schema.ex")

    assert source =~ "RustQ.Cargo"
    assert source =~ "RustQ.Syn"
    refute source =~ "Regex"
    refute source =~ ".cargo/registry"
  end

  test "SkiaSafe enum lookup uses Cargo and Syn instead of registry globs" do
    source = File.read!("lib/skia/codegen/skia_safe.ex")

    assert source =~ "RustQ.Cargo"
    assert source =~ "RustQ.Syn"
    refute source =~ ".cargo/registry"
  end

  test "native overlays stay ergonomic and validate native methods" do
    assert Skia.Codegen.CommandOverlay.validate_native!() == :ok

    source = File.read!("lib/skia/codegen/command_overlay.ex")
    refute source =~ "opts:"
    refute source =~ "args: [path:"
  end

  test "codegen tests live under test/skia/codegen" do
    root_codegen_tests =
      "test/skia/*codegen*_test.exs"
      |> Path.wildcard()
      |> Enum.reject(&String.starts_with?(&1, "test/skia/codegen/"))

    assert root_codegen_tests == []
  end

  defp codegen_source do
    "lib/skia/codegen/**/*.ex"
    |> Path.wildcard()
    |> Enum.map_join("\n", &File.read!/1)
  end
end
