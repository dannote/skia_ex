defmodule Skia.Codegen.SkiaSafe do
  @moduledoc false

  @native_manifest "native/skia_native/Cargo.toml"

  @spec enum_variants(String.t()) :: [{String.t(), String.t()}]
  def enum_variants(enum_name) when is_binary(enum_name) do
    bindings_docs!()
    |> RustQ.Syn.enum_variants!(enum_name)
    |> Enum.map(&{Macro.underscore(&1), &1})
  rescue
    RustQ.Error ->
      raise "cannot find Skia enum #{enum_name} in #{bindings_docs_path()}"
  end

  defp bindings_docs! do
    bindings_docs_path()
    |> File.read!()
  end

  defp bindings_docs_path do
    "skia-bindings"
    |> RustQ.Cargo.package_source!(manifest_path: @native_manifest)
    |> Path.join("bindings_docs.rs")
  end
end
