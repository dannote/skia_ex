defmodule Skia.Codegen.Command.Runtime do
  @moduledoc false

  alias RustQ.Meta.Type
  alias Skia.Codegen.Command.Registry

  @spec generated_registry() :: binary()
  def generated_registry do
    Registry.all()
    |> Enum.map(&runtime_command/1)
    |> :erlang.term_to_binary([:deterministic])
  end

  defp runtime_command({name, spec}) do
    runtime_spec = [
      args: Enum.map(Keyword.get(spec, :args, []), &runtime_arg/1),
      opts: Enum.map(Keyword.get(spec, :opts, []), &runtime_option/1),
      defaults: Keyword.get(spec, :defaults, []),
      doc: Registry.doc(name, spec)
    ]

    {name, runtime_spec}
  end

  defp runtime_arg({name, type}), do: {name, runtime_type(type)}

  defp runtime_option(option) do
    option
    |> Keyword.take([:name, :required])
    |> Keyword.put(:type, runtime_type(Keyword.fetch!(option, :type)))
  end

  defp runtime_type(%Type{} = type) do
    case Type.category(type) do
      {:tuple, types} -> {:tuple, Enum.map(types, &runtime_type/1)}
      :type -> {:external, type.meta.elixir_module, Map.get(type.meta, :elixir_name, :t)}
      category -> category
    end
  end
end
