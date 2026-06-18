defmodule Skia.Codegen.Commands do
  @moduledoc false

  @domains [
    Skia.Codegen.Commands.Shapes,
    Skia.Codegen.Commands.Text,
    Skia.Codegen.Commands.Images,
    Skia.Codegen.Commands.Layers,
    Skia.Codegen.Commands.Transforms,
    Skia.Codegen.Commands.Paths,
    Skia.Codegen.Commands.Clips
  ]

  @spec all() :: keyword()
  def all do
    overlays = Map.new(Skia.Codegen.CommandOverlay.overlays())

    @domains
    |> Enum.flat_map(& &1.commands())
    |> Enum.map(fn {name, spec} ->
      case Map.fetch(overlays, name) do
        {:ok, overlay} -> {name, attach_overlay(spec, overlay)}
        :error -> {name, spec}
      end
    end)
  end

  @spec names() :: [atom()]
  def names, do: Keyword.keys(all())

  @spec drawable_names() :: [atom()]
  def drawable_names do
    names() --
      [
        :save,
        :save_layer,
        :restore,
        :translate,
        :scale,
        :rotate,
        :rotate_at,
        :concat,
        :push_style,
        :pop_style
      ]
  end

  @spec fetch!(atom()) :: keyword()
  def fetch!(name), do: Keyword.fetch!(all(), name)

  @spec doc(atom(), keyword()) :: String.t()
  def doc(name, spec) do
    [
      "Adds a `#{name}` command to the document.",
      native_signature(spec),
      native_source(spec),
      native_doc(spec)
    ]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join("\n\n")
  end

  defp attach_overlay(spec, overlay) do
    native_ref = Keyword.fetch!(overlay, :native)
    native = Skia.Codegen.NativeSchema.descriptor!(native_ref)

    spec
    |> Keyword.put(:overlay, overlay)
    |> Keyword.put(:native, native)
  end

  defp native_signature(spec) do
    with %{ref: ref, method: %{signature_ast: signature}} <- Keyword.get(spec, :native) do
      "Native: `#{RustQ.NativeRef.format(ref)}`\n\nNative signature: `#{RustQ.Syn.Signature.render(signature)}`"
    else
      _ -> nil
    end
  end

  defp native_source(spec) do
    with %{method: %{source_path: path, source_line: line}, source_url: source_url} <-
           Keyword.get(spec, :native),
         true <- is_binary(path),
         true <- is_integer(line) do
      relative = Path.relative_to(path, Skia.Codegen.NativeSchema.source_root!())

      if source_url do
        "Native source: [`#{relative}:#{line}`](#{source_url})"
      else
        "Native source: `#{relative}:#{line}`"
      end
    else
      _ -> nil
    end
  end

  defp native_doc(spec) do
    with %{ref: ref, method: %{docs: [_ | _] = docs}} <- Keyword.get(spec, :native) do
      ["Native `#{RustQ.NativeRef.format(ref)}` docs:" | docs]
      |> Enum.map(&normalize_native_doc_line/1)
      |> Enum.join("\n")
    else
      _ -> nil
    end
  end

  defp normalize_native_doc_line(line) do
    line
    |> String.replace(~r/\[`(?:crate::)?([^\]]+)`\]/, "`\\1`")
  end
end
