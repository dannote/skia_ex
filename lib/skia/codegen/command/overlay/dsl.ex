defmodule Skia.Codegen.Command.Overlay.DSL do
  @moduledoc false

  defmacro __using__(_opts) do
    quote do
      import Skia.Codegen.Command.Overlay.DSL, only: [command: 2]
      Module.register_attribute(__MODULE__, :commands, accumulate: true)
      @before_compile Skia.Codegen.Command.Overlay.DSL
    end
  end

  alias RustQ.Native.Ref, as: NativeRef

  @allowed_keys [:native, :expands_to, :expand, :defaults]
  @forbidden_schema_keys [:args, :opts, :native_refs, :native_shape]

  defmacro command(name, opts) do
    opts = normalize_overlay!(name, opts)

    quote bind_quoted: [name: name, opts: Macro.escape(opts)] do
      @commands {name, opts}
    end
  end

  defp normalize_overlay!(name, opts) when is_atom(name) and is_list(opts) do
    keys = Keyword.keys(opts)

    case keys -- @allowed_keys do
      [] -> :ok
      extra -> raise ArgumentError, "unknown command overlay keys for #{name}: #{inspect(extra)}"
    end

    if Enum.any?(keys, &(&1 in @forbidden_schema_keys)) do
      raise ArgumentError,
            "command overlay for #{name} must not duplicate args/opts/native_refs/native_shape schema"
    end

    opts
    |> update_if_present(:native, &normalize_native_ref!(name, &1))
    |> update_if_present(:expands_to, fn refs ->
      Enum.map(refs, &normalize_native_ref!(name, &1))
    end)
  end

  defp normalize_overlay!(name, _opts),
    do: raise(ArgumentError, "invalid command overlay #{inspect(name)}")

  defp update_if_present(opts, key, fun) do
    if Keyword.has_key?(opts, key), do: Keyword.update!(opts, key, fun), else: opts
  end

  defp normalize_native_ref!(_name, {{:., _, [{:__aliases__, _, [target]}, method]}, _, []})
       when is_atom(target) and is_atom(method) do
    NativeRef.new(Atom.to_string(target), Atom.to_string(method), package: "skia-safe")
  end

  defp normalize_native_ref!(_name, %NativeRef{} = ref), do: ref

  defp normalize_native_ref!(name, ref) do
    raise ArgumentError,
          "command overlay #{name} native ref must be Module.method, got: #{Macro.to_string(ref)}"
  end

  defmacro __before_compile__(_env) do
    quote do
      @spec overlays() :: keyword()
      def overlays do
        @commands
        |> Enum.reverse()
      end
    end
  end
end
