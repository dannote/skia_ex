defmodule Skia.Codegen.Command.Runtime do
  @moduledoc false

  alias RustQ.Meta.Type
  alias Skia.Codegen.Command.Registry

  @spec generated_registry() :: String.t()
  def generated_registry do
    commands = Enum.map(Registry.all(), &runtime_command/1)

    quoted =
      quote do
        defmodule Skia.Command.Registry do
          @moduledoc false

          @commands unquote(Macro.escape(commands))
          @non_drawable ~w(save save_layer restore translate scale rotate rotate_at concat push_style pop_style)a

          @spec all() :: keyword()
          def all, do: @commands

          @spec names() :: [atom()]
          def names, do: Keyword.keys(@commands)

          @spec drawable_names() :: [atom()]
          def drawable_names, do: names() -- @non_drawable

          @spec fetch!(atom()) :: keyword()
          def fetch!(name), do: Keyword.fetch!(@commands, name)

          @spec doc(atom(), keyword()) :: String.t()
          def doc(_name, spec), do: Keyword.fetch!(spec, :doc)
        end
      end

    formatted = quoted |> Macro.to_string() |> Code.format_string!()
    IO.iodata_to_binary(["# ex_dna:disable-for-this-file\n", formatted, "\n"])
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
