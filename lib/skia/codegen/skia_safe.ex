defmodule Skia.Codegen.SkiaSafe do
  @moduledoc false

  @bindings_docs "skia-bindings-*/bindings_docs.rs"
  @safe_src "skia-safe-*/src"

  @spec enum_variants(String.t()) :: [{String.t(), String.t()}]
  def enum_variants(enum_name) when is_binary(enum_name) do
    bindings_docs!()
    |> RustQ.Syn.enum_variants!(enum_name)
    |> Enum.map(&{Macro.underscore(&1), &1})
  rescue
    RustQ.Error ->
      raise "cannot find Skia enum #{enum_name} in #{bindings_docs_path()}"
  end

  @spec native_refs(keyword()) :: [String.t()]
  def native_refs(spec) do
    spec
    |> Keyword.get(:native_refs, [])
    |> Enum.filter(&native_ref_exists?/1)
  end

  @spec rust_doc_snippet(String.t()) :: String.t() | nil
  def rust_doc_snippet("skia_safe::" <> path) do
    [module, function] = String.split(path, "::", parts: 2)

    with {:ok, source} <- rust_source(module),
         {:ok, docs} <- extract_rust_docs(source, function) do
      docs
      |> Enum.take(4)
      |> Enum.map_join("\n", &"> #{&1}")
    else
      _ -> nil
    end
  end

  def rust_doc_snippet(_ref), do: nil

  @spec native_ref_exists?(String.t()) :: boolean()
  def native_ref_exists?("skia_safe::" <> path) do
    [module, function] = String.split(path, "::", parts: 2)

    case rust_source(module) do
      {:ok, source} -> String.contains?(source, "fn #{function}")
      :error -> false
    end
  end

  def native_ref_exists?(_ref), do: true

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

  defp rust_source("Canvas"), do: read_skia_safe_source("core/canvas.rs")
  defp rust_source("Font"), do: read_skia_safe_source("core/font.rs")
  defp rust_source("ImageFilter"), do: read_skia_safe_source("effects/image_filters.rs")
  defp rust_source("Path"), do: read_skia_safe_source("pathops.rs")
  defp rust_source("path_utils"), do: read_skia_safe_source("core/path_utils.rs")
  defp rust_source("pathops"), do: read_skia_safe_source("pathops.rs")
  defp rust_source(_module), do: :error

  defp read_skia_safe_source(relative_path) do
    [System.user_home!(), ".cargo/registry/src/*", @safe_src, relative_path]
    |> Path.join()
    |> Path.wildcard()
    |> Enum.sort(:desc)
    |> List.first()
    |> case do
      nil -> :error
      path -> File.read(path)
    end
  end

  defp extract_rust_docs(source, function) do
    lines = String.split(source, "\n")
    index = Enum.find_index(lines, &String.contains?(&1, "fn #{function}"))

    if index do
      docs =
        lines
        |> Enum.take(index)
        |> Enum.reverse()
        |> Enum.take_while(&(String.trim_leading(&1) |> String.starts_with?("///")))
        |> Enum.reverse()
        |> Enum.map(&clean_rust_doc_line/1)
        |> Enum.reject(&(&1 == ""))

      if docs == [], do: :error, else: {:ok, docs}
    else
      :error
    end
  end

  defp clean_rust_doc_line(line) do
    line
    |> String.trim_leading()
    |> String.replace_prefix("///", "")
    |> String.trim()
  end
end
