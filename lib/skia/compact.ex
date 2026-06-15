defmodule Skia.Compact do
  import Bitwise

  @moduledoc "Compact, Erlang-term-friendly command batch representation."

  alias Skia.{Command, CommandSpec, Document}

  @op_ids CommandSpec.all()
          |> Enum.flat_map(fn {name, spec} -> [name, Keyword.get(spec, :op, name)] end)
          |> Enum.uniq()
          |> Enum.with_index(1)
          |> Map.new()

  @segment_ids %{
    move_to: 1,
    line_to: 2,
    quad_to: 3,
    conic_to: 4,
    cubic_to: 5,
    r_move_to: 6,
    r_line_to: 7,
    r_quad_to: 8,
    r_conic_to: 9,
    r_cubic_to: 10,
    arc_to: 11,
    r_arc_to: 12,
    rrect: 13,
    close: 14
  }

  @type compact_value :: term()
  @type compact_command :: {pos_integer(), [compact_value()], keyword(compact_value())}
  @type compact_batch :: {pos_integer(), pos_integer(), [compact_command()]}

  @spec op_id(atom()) :: pos_integer()
  def op_id(op), do: Map.fetch!(@op_ids, op)

  @spec from_document(Document.t()) :: compact_batch()
  def from_document(%Document{} = document) do
    {document.width, document.height, Enum.map(Skia.commands(document), &from_command/1)}
  end

  @spec from_command(Command.t()) :: compact_command()
  def from_command(%Command{} = command) do
    {op_id(command.op), Enum.map(command.args, &compact_value/1), compact_opts(command.opts)}
  end

  @spec to_binary(Document.t()) :: binary()
  def to_binary(%Document{} = document),
    do: document |> from_document() |> :erlang.term_to_binary(compressed: 1)

  defp compact_opts(opts), do: Enum.map(opts, fn {key, value} -> {key, compact_value(value)} end)

  defp compact_value({:rgba, r, g, b, a}), do: {:c, rgba_u32(r, g, b, a)}
  defp compact_value(%Skia.Path{svg: svg}) when is_binary(svg), do: {:svg, svg}

  defp compact_value(%Skia.Path{} = path) do
    {:p, path |> Skia.Path.segments() |> Enum.map(&compact_segment/1)}
  end

  defp compact_value(%_struct{} = value), do: value

  defp compact_value(list) when is_list(list), do: Enum.map(list, &compact_value/1)

  defp compact_value(tuple) when is_tuple(tuple),
    do: tuple |> Tuple.to_list() |> Enum.map(&compact_value/1) |> List.to_tuple()

  defp compact_value(value), do: value

  defp compact_segment(:close), do: {@segment_ids.close}

  defp compact_segment(segment) when is_tuple(segment) do
    [op | values] = Tuple.to_list(segment)
    List.to_tuple([Map.fetch!(@segment_ids, op) | Enum.map(values, &compact_value/1)])
  end

  defp rgba_u32(r, g, b, a), do: r <<< 24 ||| g <<< 16 ||| b <<< 8 ||| a
end
