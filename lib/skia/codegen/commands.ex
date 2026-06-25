defmodule Skia.Codegen.Commands do
  @moduledoc false

  alias RustQ.Native.Ref, as: NativeRef
  alias RustQ.Syn
  alias RustQ.Syn.Doc
  alias Skia.Codegen.CommandOverlay
  alias Skia.Codegen.Commands.{Clips, Images, Layers, Paths, Shapes, Text, Transforms}
  alias Skia.Codegen.NativeSchema

  @domains [Shapes, Text, Images, Layers, Transforms, Paths, Clips]

  @spec all() :: keyword()
  def all do
    overlays = Map.new(CommandOverlay.overlays())

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
      composite_native_refs(spec),
      native_source(spec),
      native_doc(spec)
    ]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join("\n\n")
  end

  defp attach_overlay(spec, overlay) do
    spec
    |> Keyword.put(:overlay, overlay)
    |> attach_native(overlay)
    |> attach_expands_to(overlay)
  end

  defp attach_native(spec, overlay) do
    case Keyword.fetch(overlay, :native) do
      {:ok, native_ref} ->
        Keyword.put(spec, :native, NativeSchema.descriptor!(native_ref))

      :error ->
        spec
    end
  end

  defp attach_expands_to(spec, overlay) do
    refs = Keyword.get(overlay, :expands_to, [])
    descriptors = Enum.map(refs, &NativeSchema.descriptor!/1)

    if descriptors == [], do: spec, else: Keyword.put(spec, :expands_to, descriptors)
  end

  defp native_signature(spec) do
    case Keyword.get(spec, :native) do
      %{ref: ref, method: %{signature_ast: signature}} ->
        "Native: `#{NativeRef.format(ref)}`\n\nNative signature: `#{Syn.Signature.render(signature)}`"

      _other ->
        nil
    end
  end

  defp composite_native_refs(spec) do
    case Keyword.get(spec, :expands_to, []) do
      [] ->
        nil

      descriptors ->
        refs =
          Enum.map_join(descriptors, ", ", fn %{ref: ref} -> "`#{NativeRef.format(ref)}`" end)

        "Implemented via native calls: #{refs}"
    end
  end

  defp native_source(spec) do
    with %{method: %{source_path: path, source_line: line}, source_url: source_url} <-
           Keyword.get(spec, :native),
         true <- is_binary(path),
         true <- is_integer(line) do
      relative = Path.relative_to(path, NativeSchema.source_root!())

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
    case Keyword.get(spec, :native) do
      %{ref: ref, method: %{docs: [_ | _] = docs}} ->
        ["Native `#{NativeRef.format(ref)}` docs:" | docs]
        |> Doc.markdown()

      _other ->
        nil
    end
  end
end
