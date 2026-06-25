defmodule Skia.Codegen.EnumsTest do
  use ExUnit.Case, async: true

  alias RustQ.Meta.Type
  alias RustQ.Native.EnumDescriptor, as: NativeEnumDescriptor
  alias RustQ.Syn
  alias Skia.Codegen
  alias Skia.Codegen.Commands
  alias Skia.Codegen.Enums
  alias Skia.Codegen.SkiaSafe

  test "top-level enum generation delegates to enum module" do
    assert Codegen.generated_enums() == Enums.generated()
  end

  test "SkiaSafe resolves native enum descriptors through RustQ" do
    assert %NativeEnumDescriptor{
             package: "skia-bindings",
             name: "SkClipOp",
             enum: %Syn.Enum{variants: ["Difference", "Intersect"]},
             source_url: source_url
           } = SkiaSafe.enum_descriptor!("SkClipOp")

    assert source_url =~ "https://docs.rs/crate/skia-bindings/"
  end

  test "enum metadata includes command option enums and extra native enums" do
    defs = Enums.defs()

    assert Map.has_key?(defs, :blend_mode)
    assert Map.has_key?(defs, :fill_rule)
    assert Map.has_key?(defs, :encoded_image_format)
  end

  test "command enum markers are backed by API enum names" do
    command_enums = command_enum_names()
    api_enums = Enums.api_enums()

    assert MapSet.subset?(command_enums, api_enums |> Map.keys() |> MapSet.new())
    assert Map.fetch!(api_enums, :stroke_cap) == "SkPaint_Cap"
    assert Map.fetch!(api_enums, :stroke_join) == "SkPaint_Join"
  end

  test "API enum names resolve through RustQ native descriptors" do
    for {api_name, native_name} <- Enums.api_enums() do
      spec = Enums.spec!(api_name)

      assert Keyword.fetch!(spec, :skia) == native_name
      assert %NativeEnumDescriptor{name: ^native_name} = Keyword.fetch!(spec, :descriptor)
    end
  end

  defp command_enum_names do
    Commands.all()
    |> Enum.flat_map(fn {_name, spec} ->
      Keyword.get(spec, :args, []) ++ Keyword.get(spec, :opts, [])
    end)
    |> Enum.map(fn
      {_name, %Type{} = type} -> type
      spec when is_list(spec) -> Keyword.fetch!(spec, :type)
    end)
    |> Enum.flat_map(&enum_names/1)
    |> MapSet.new()
  end

  defp enum_names(%Type{kind: :enum, meta: %{elixir_name: name}}), do: [name]

  defp enum_names(%Type{kind: :tuple, meta: %{elements: elements}}),
    do: Enum.flat_map(elements, &enum_names/1)

  defp enum_names(_type), do: []
end
