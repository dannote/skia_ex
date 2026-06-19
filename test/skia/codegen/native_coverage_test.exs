defmodule Skia.Codegen.NativeCoverageTest do
  use ExUnit.Case, async: true

  test "direct native commands have descriptor docs metadata" do
    direct =
      Skia.Codegen.Commands.all()
      |> Enum.filter(fn {_name, spec} -> Keyword.has_key?(spec, :native) end)

    assert direct != []

    for {name, spec} <- direct do
      assert %RustQ.NativeDescriptor{method: method, source_url: source_url} = spec[:native],
             "#{name} should carry a native descriptor"

      assert %RustQ.Syn.Signature{} = method.signature_ast,
             "#{name} should carry a structural native signature"

      assert is_binary(source_url), "#{name} should carry a source URL"
    end
  end

  test "composite native commands declare expanded descriptors without direct native docs" do
    composites =
      Skia.Codegen.Commands.all()
      |> Enum.filter(fn {_name, spec} -> Keyword.has_key?(spec, :expands_to) end)

    assert Keyword.keys(composites) == [:clip_circle]

    for {name, spec} <- composites do
      refute Keyword.has_key?(spec, :native), "#{name} should not pretend to be direct native"
      assert [%RustQ.NativeDescriptor{} | _] = spec[:expands_to]
    end
  end

  test "commands without native mapping are visible for follow-up" do
    unmapped =
      Skia.Codegen.Commands.all()
      |> Enum.reject(fn {_name, spec} ->
        Keyword.has_key?(spec, :native) or Keyword.has_key?(spec, :expands_to)
      end)
      |> Keyword.keys()

    assert unmapped == [:text, :push_style, :pop_style, :path_op, :path_outline]
  end
end
