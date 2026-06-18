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
      elixir_shape(spec),
      native_signature(spec),
      native_source(spec),
      native_doc(spec)
    ]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join("\n\n")
  end

  defp elixir_shape(spec) do
    [args_doc(spec), opts_doc(spec), defaults_doc(spec)]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> case do
      [] -> nil
      sections -> Enum.join(sections, "\n\n")
    end
  end

  defp args_doc(spec) do
    case Keyword.get(spec, :args, []) do
      [] ->
        nil

      args ->
        "Elixir arguments:\n" <>
          Enum.map_join(args, "\n", fn {name, type} -> "  * `#{name}` - #{type_doc(type)}" end)
    end
  end

  defp opts_doc(spec) do
    case Keyword.get(spec, :opts, []) do
      [] ->
        nil

      opts ->
        "Elixir options:\n" <>
          Enum.map_join(opts, "\n", fn opt ->
            name = Keyword.fetch!(opt, :name)
            suffix = if Keyword.get(opt, :required, false), do: " required", else: ""
            "  * `#{name}` - #{type_doc(Keyword.fetch!(opt, :type))}#{suffix}"
          end)
    end
  end

  defp defaults_doc(spec) do
    case Keyword.get(spec, :defaults, []) do
      [] ->
        nil

      defaults ->
        "Elixir defaults:\n" <>
          Enum.map_join(defaults, "\n", fn {name, value} ->
            "  * `#{name}` - `#{inspect(value)}`"
          end)
    end
  end

  defp type_doc({:enum, name, _opts}), do: "`:#{name}`"

  defp type_doc({:tuple, types}) do
    "`{#{Enum.map_join(types, ", ", &type_name/1)}}`"
  end

  defp type_doc(type), do: "`#{type_name(type)}`"

  defp type_name({:enum, name, _opts}), do: name
  defp type_name(type), do: to_string(type)

  defp attach_overlay(spec, overlay) do
    native_ref = Keyword.fetch!(overlay, :native)
    native = Skia.Codegen.NativeRef.descriptor!(native_ref)

    spec
    |> Keyword.put(:overlay, overlay)
    |> Keyword.put(:native, native)
  end

  defp native_signature(spec) do
    with %{method: method} = native <- Keyword.get(spec, :native),
         ref = Skia.Codegen.NativeRef.new(native.target, native.name) do
      args = Enum.map_join(method.args, ", ", &native_arg/1)
      returns = method.returns || "()"
      "Native: `#{Skia.Codegen.NativeRef.format(ref)}(#{args}) -> #{returns}`"
    else
      _ -> nil
    end
  end

  defp native_arg(%RustQ.Syn.Arg{name: nil, type: type}), do: type
  defp native_arg(%RustQ.Syn.Arg{name: name, type: type}), do: "#{name}: #{type}"

  defp native_source(spec) do
    with %{method: %{source_path: path, source_line: line}} <- Keyword.get(spec, :native),
         true <- is_binary(path),
         true <- is_integer(line) do
      relative = Path.relative_to(path, Skia.Codegen.NativeSchema.source_root!())
      "Native source: `#{relative}:#{line}`"
    else
      _ -> nil
    end
  end

  defp native_doc(spec) do
    with %{method: %{docs: [_ | _] = docs}} = native <- Keyword.get(spec, :native),
         ref = Skia.Codegen.NativeRef.new(native.target, native.name) do
      ["Native `#{Skia.Codegen.NativeRef.format(ref)}` docs:" | docs]
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
