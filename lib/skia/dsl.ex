defmodule Skia.DSL do
  @moduledoc """
  Readable `do`/`end` DSL for building batched drawing documents.

  The DSL rewrites blocks to the same fluent functions exposed by `Skia`, so
  both APIs share validation and command normalization.
  """

  alias Skia.CommandSpec

  defmacro __using__(_opts) do
    quote do
      import Skia.DSL
    end
  end

  defmacro canvas(width, height, do: block) do
    initial = quote do: Skia.canvas(unquote(width), unquote(height))
    compile_document_block(block, initial)
  end

  defp compile_document_block(block, initial) do
    block
    |> statements()
    |> Enum.reduce(initial, &compile_document_statement/2)
  end

  defp compile_document_statement({:group, _meta, args}, acc) do
    {opts, block} = split_block_args!(:group, args)
    document = Macro.unique_var(:document, __MODULE__)

    quote do
      Skia.group(unquote(acc), unquote(opts), fn unquote(document) ->
        unquote(compile_document_block(block, document))
      end)
    end
  end

  defp compile_document_statement({:style, _meta, args}, acc) do
    compile_scoped_statement(:style, args, acc)
  end

  defp compile_document_statement({:layer, _meta, args}, acc) do
    compile_scoped_statement(:layer, args, acc)
  end

  defp compile_document_statement({:path, _meta, args}, acc) do
    {opts, block} = split_block_args!(:path, args)
    path = compile_path_block(block)

    quote do
      Skia.path(unquote(acc), unquote(path), unquote(opts))
    end
  end

  defp compile_document_statement({name, _meta, args}, acc)
       when is_atom(name) and is_list(args) do
    if name in CommandSpec.drawable_names() do
      quote do
        apply(Skia, unquote(name), [unquote(acc) | unquote(args)])
      end
    else
      raise ArgumentError, "unknown Skia DSL command #{name}"
    end
  end

  defp compile_document_statement(other, _acc) do
    raise ArgumentError, "unsupported Skia DSL expression #{Macro.to_string(other)}"
  end

  defp compile_scoped_statement(name, args, acc) do
    {opts, block} = split_block_args!(name, args)
    document = Macro.unique_var(:document, __MODULE__)

    quote do
      apply(Skia, unquote(name), [
        unquote(acc),
        unquote(opts),
        fn unquote(document) ->
          unquote(compile_document_block(block, document))
        end
      ])
    end
  end

  defp compile_path_block(block) do
    block
    |> statements()
    |> Enum.reduce(quote(do: Skia.Path.new()), &compile_path_statement/2)
  end

  defp compile_path_statement({name, _meta, args}, acc)
       when name in [
              :move_to,
              :line_to,
              :quad_to,
              :conic_to,
              :cubic_to,
              :r_move_to,
              :r_line_to,
              :r_quad_to,
              :r_conic_to,
              :r_cubic_to,
              :arc_to,
              :r_arc_to,
              :rrect
            ] and is_list(args) do
    quote do
      apply(Skia.Path, unquote(name), [unquote(acc) | unquote(args)])
    end
  end

  defp compile_path_statement({:close, _meta, args}, acc) when args in [[], nil] do
    quote do
      Skia.Path.close(unquote(acc))
    end
  end

  defp compile_path_statement(other, _acc) do
    raise ArgumentError, "unsupported Skia path DSL expression #{Macro.to_string(other)}"
  end

  defp split_block_args!(name, args) do
    case args do
      [opts] when is_list(opts) ->
        case Keyword.pop(opts, :do) do
          {nil, _opts} ->
            raise ArgumentError, "#{name} requires options followed by a do/end block"

          {block, opts} ->
            {opts, block}
        end

      [opts, [do: block]] when is_list(opts) ->
        {opts, block}

      [[do: block]] ->
        {[], block}

      _ ->
        raise ArgumentError, "#{name} requires options followed by a do/end block"
    end
  end

  defp statements({:__block__, _meta, statements}), do: statements
  defp statements(statement), do: [statement]
end
