defmodule Skia.Codegen.NativeDriftTest do
  use ExUnit.Case, async: true

  test "direct native command refs are visible in generated Rust method calls" do
    generated_methods = generated_method_references()

    missing =
      Skia.Codegen.Commands.all()
      |> Enum.flat_map(fn {name, spec} ->
        case Keyword.fetch(spec, :native) do
          {:ok, %RustQ.NativeDescriptor{ref: %RustQ.NativeRef{member: member}}} ->
            if member in generated_methods, do: [], else: [{name, member}]

          :error ->
            []
        end
      end)

    assert missing == []
  end

  test "composite command refs are visible in generated Rust method calls" do
    generated_methods = generated_method_references()

    missing =
      Skia.Codegen.Commands.all()
      |> Enum.flat_map(fn {name, spec} ->
        spec
        |> Keyword.get(:expands_to, [])
        |> Enum.reject(fn %RustQ.NativeDescriptor{ref: %RustQ.NativeRef{member: member}} ->
          member in generated_methods
        end)
        |> Enum.map(fn %RustQ.NativeDescriptor{ref: %RustQ.NativeRef{member: member}} ->
          {name, member}
        end)
      end)

    assert missing == []
  end

  defp generated_method_references do
    "native/skia_native/src/generated_*.rs"
    |> Path.wildcard()
    |> Enum.flat_map(fn path -> path |> File.read!() |> RustQ.Syn.method_references!() end)
    |> Enum.uniq()
  end
end
