defmodule Skia.Codegen.CommandDSL do
  @moduledoc """
  Small valid-Elixir command DSL for simple Skia commands.

  This layer expands command declarations such as save/restore into real
  `@spec` + `defrust` definitions. Use it when the command implementation is
  naturally expressible as Rusty Elixir; use focused impl modules plus
  `RustQ.Meta.quoted/2` when Skia must provide generated Rust signature types.
  """

  defmacro __using__(_opts) do
    quote do
      import Skia.Codegen.CommandDSL
      alias RustQ.Type, as: R
    end
  end

  defmacro defimpl_handler(name, do: body) do
    impl_definition(name, body)
  end

  defmacro defcommand(name, do: block) do
    name
    |> parse_command!(block)
    |> command_definition()
  end

  defmacro defcommands(opts) when is_list(opts) do
    from_ast = Keyword.fetch!(opts, :from)
    {commands, _binding} = Code.eval_quoted(from_ast, [], __CALLER__)

    commands
    |> select_commands(opts)
    |> Enum.map(fn {name, spec} -> command_from_spec(name, spec) |> command_definition() end)
    |> then(&{:__block__, [], &1})
  end

  defp parse_command!(name, block) do
    block
    |> block_expressions()
    |> Enum.reduce([name: name], fn
      {:handler, _, [handler]}, acc ->
        Keyword.put(acc, :handler, handler)

      {:impl, _, [[do: body]]}, acc ->
        Keyword.put(acc, :body, body)

      other, _acc ->
        raise ArgumentError, "unsupported defcommand entry: #{Macro.to_string(other)}"
    end)
  end

  defp command_from_spec(name, spec) do
    handler = Keyword.fetch!(spec, :handler)

    [name: name, handler: handler, body: simple_canvas_body!(spec)]
  end

  defp simple_canvas_body!(spec) do
    case get_in(spec, [:layer, :body]) do
      [{:call, "canvas", method, []}] ->
        {:__block__, [], [{{:., [], [{:canvas, [], nil}, method]}, [], []}, :ok]}

      other ->
        raise ArgumentError, "unsupported defcommands body: #{inspect(other)}"
    end
  end

  defp command_definition(command) do
    handler = Keyword.fetch!(command, :handler)
    impl = Keyword.get(command, :impl, String.to_atom("#{handler}_impl"))
    body = Keyword.fetch!(command, :body)

    quote do
      unquote(handler_definition(handler, impl: impl))
      unquote(impl_definition(impl, body))
    end
  end

  defp select_commands(commands, opts) do
    only = opts |> Keyword.get(:only) |> List.wrap()
    except = opts |> Keyword.get(:except, []) |> List.wrap()

    commands
    |> then(fn commands -> if only == [], do: commands, else: Keyword.take(commands, only) end)
    |> Keyword.drop(except)
  end

  defp block_expressions({:__block__, _, expressions}), do: expressions
  defp block_expressions(expression), do: [expression]

  defp handler_definition(name, opts) do
    impl = Keyword.fetch!(opts, :impl)

    quote do
      @spec unquote(name)(R.ref(Canvas.t()), term()) :: R.nif_result(R.unit())
      defrust unquote(name)(canvas, _command) do
        unquote(impl)(canvas)
      end
    end
  end

  defp impl_definition(name, body) do
    quote do
      @spec unquote(name)(R.ref(Canvas.t())) :: R.nif_result(R.unit())
      defrust unquote(name)(canvas) do
        unquote(body)
      end
    end
  end
end
