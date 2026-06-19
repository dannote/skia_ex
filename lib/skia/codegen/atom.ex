defmodule Skia.Codegen.Atom do
  @moduledoc false

  @identifier ~r/^[a-z][a-z0-9_]*[!?]?$/

  @spec identifier!(String.t()) :: atom()
  def identifier!(name) when is_binary(name) do
    if String.match?(name, @identifier) do
      :erlang.binary_to_atom(name, :utf8)
    else
      raise ArgumentError, "invalid generated atom identifier #{inspect(name)}"
    end
  end
end
