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
    Skia.Codegen.CommandOverlay.validate_native!()
    overlays = Map.new(Skia.Codegen.CommandOverlay.overlays())

    @domains
    |> Enum.flat_map(& &1.commands())
    |> Enum.map(fn {name, spec} ->
      case Map.fetch(overlays, name) do
        {:ok, overlay} -> {name, Keyword.put(spec, :overlay, overlay)}
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
    ["Adds a `#{name}` command to the document.", native_doc(spec)]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join("\n\n")
  end

  defp native_doc(spec) do
    with overlay when is_list(overlay) <- Keyword.get(spec, :overlay),
         {target, method} <- Keyword.fetch!(overlay, :native),
         %{method: %{docs: docs}} <- Skia.Codegen.NativeSchema.descriptor!(target, method),
         [_ | _] <- docs do
      ["Native `skia_safe::#{target}::#{method}` docs:" | docs]
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
