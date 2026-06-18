defmodule Skia.Codegen.SkiaSafe do
  @moduledoc false

  @bindings_docs "skia-bindings-*/bindings_docs.rs"

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
    [System.user_home!(), ".cargo/registry/src/*", @bindings_docs]
    |> Path.join()
    |> Path.wildcard()
    |> Enum.sort(:desc)
    |> List.first()
    |> case do
      nil -> raise "cannot find skia-bindings bindings_docs.rs"
      path -> path
    end
  end
end
