defmodule Skia.Codegen.SkiaSafe do
  @moduledoc false

  alias RustQ.Native.EnumDescriptor, as: NativeEnumDescriptor
  alias RustQ.Syn.Index

  @native_manifest "native/skia_native/Cargo.toml"

  @spec enum_descriptor!(String.t()) :: NativeEnumDescriptor.t()
  def enum_descriptor!(enum_name) when is_binary(enum_name) do
    NativeEnumDescriptor.resolve!(bindings_index(), enum_name, package: "skia-bindings")
  rescue
    error in [RuntimeError] ->
      reraise RuntimeError,
              [message: "cannot find Skia enum #{enum_name} in skia-bindings: #{error.message}"],
              __STACKTRACE__
  end

  @spec enum_variants(String.t()) :: [{String.t(), String.t()}]
  def enum_variants(enum_name) when is_binary(enum_name) do
    enum_name
    |> enum_descriptor!()
    |> then(& &1.enum.variants)
    |> Enum.map(&{Macro.underscore(&1), &1})
  end

  defp bindings_index do
    Index.cached_package("skia-bindings", manifest_path: @native_manifest)
  end
end
