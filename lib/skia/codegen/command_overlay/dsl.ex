defmodule Skia.Codegen.CommandOverlay.DSL do
  @moduledoc false

  defmacro __using__(_opts) do
    quote do
      import Skia.Codegen.CommandOverlay.DSL, only: [command: 2]
      Module.register_attribute(__MODULE__, :commands, accumulate: true)
      @before_compile Skia.Codegen.CommandOverlay.DSL
    end
  end

  @allowed_keys [:native, :expand, :defaults, :native_shape]
  @forbidden_schema_keys [:args, :opts, :native_refs]

  defmacro command(name, opts) do
    validate_overlay!(name, opts)

    quote bind_quoted: [name: name, opts: opts] do
      @commands {name, opts}
    end
  end

  defp validate_overlay!(name, opts) when is_atom(name) and is_list(opts) do
    keys = Keyword.keys(opts)

    case keys -- @allowed_keys do
      [] -> :ok
      extra -> raise ArgumentError, "unknown command overlay keys for #{name}: #{inspect(extra)}"
    end

    if Enum.any?(keys, &(&1 in @forbidden_schema_keys)) do
      raise ArgumentError,
            "command overlay for #{name} must not duplicate args/opts/native_refs schema"
    end
  end

  defp validate_overlay!(name, _opts),
    do: raise(ArgumentError, "invalid command overlay #{inspect(name)}")

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
