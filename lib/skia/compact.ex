defmodule Skia.Compact do
  @moduledoc "Compact, Erlang-term-friendly command batch representation."

  alias Skia.{Command, Document}

  @type compact_command :: {atom(), [term()], keyword()}
  @type compact_batch :: {pos_integer(), pos_integer(), [compact_command()]}

  @spec from_document(Document.t()) :: compact_batch()
  def from_document(%Document{} = document) do
    {document.width, document.height, Enum.map(Skia.commands(document), &from_command/1)}
  end

  @spec from_command(Command.t()) :: compact_command()
  def from_command(%Command{} = command), do: {command.op, command.args, command.opts}

  @spec to_binary(Document.t()) :: binary()
  def to_binary(%Document{} = document),
    do: document |> from_document() |> :erlang.term_to_binary()
end
