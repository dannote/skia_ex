defmodule Skia.Codegen.Rusty.Dispatch do
  @moduledoc """
  Rusty-Elixir dispatch helpers for generated command routing.
  """

  use RustQ.Meta

  alias RustQ.Type, as: R
  alias Skia.Codegen.Command.Registry, as: Commands

  defmacro compact_op_case(id) do
    clauses =
      Enum.map(compact_ops(), fn {atom, value} ->
        {:->, [], [[value], {:ok, atom}]}
      end) ++
        [
          {:->, [], [[{:_, [], Elixir}], {:error, {:badarg, [], []}}]}
        ]

    {:case, [], [id, [do: clauses]]}
  end

  @spec compact_op_atom(R.i64()) :: R.nif_result(R.atom())
  defrust compact_op_atom(id) do
    compact_op_case(id)
  end

  defp compact_ops do
    Commands.all()
    |> Enum.flat_map(fn {name, spec} -> [name, Keyword.get(spec, :op, name)] end)
    |> Enum.uniq()
    |> Enum.with_index(1)
  end
end
