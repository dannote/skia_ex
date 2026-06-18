defmodule Skia.Codegen.SkiaSafe do
  @moduledoc false

  @native_manifest "native/skia_native/Cargo.toml"

  @spec enum_descriptor!(String.t()) :: RustQ.NativeEnumDescriptor.t()
  def enum_descriptor!(enum_name) when is_binary(enum_name) do
    RustQ.NativeEnumDescriptor.resolve!(bindings_index(), enum_name, package: "skia-bindings")
  rescue
    RuntimeError ->
      raise "cannot find Skia enum #{enum_name} in skia-bindings"
  end

  @spec enum_variants(String.t()) :: [{String.t(), String.t()}]
  def enum_variants(enum_name) when is_binary(enum_name) do
    enum_name
    |> enum_descriptor!()
    |> then(& &1.enum.variants)
    |> Enum.map(&{Macro.underscore(&1), &1})
  end

  defp bindings_index do
    :persistent_term.get({__MODULE__, :bindings_index}, nil) || build_bindings_index()
  end

  defp build_bindings_index do
    index = RustQ.Syn.Index.from_package("skia-bindings", manifest_path: @native_manifest)
    :persistent_term.put({__MODULE__, :bindings_index}, index)
    index
  end
end
