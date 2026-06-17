defmodule Skia.Codegen.Defrust do
  @moduledoc false

  alias RustQ.Rust
  alias RustQ.Rust.AST
  alias RustQ.Rust.AST.Builder, as: A

  defmacro __using__(_opts) do
    quote do
      import Skia.Codegen.Defrust
      alias RustQ.Type, as: R
    end
  end

  defmacro defhandler(name, opts) do
    ast = handler_ast(name, opts)
    item = Rust.item(RustQ.Rust.AST.Render.render_item(ast))
    source = RustQ.Rust.AST.Render.render_item(ast)

    quote do
      @doc false
      def __rustq_asts__, do: [unquote(Macro.escape(ast))]

      @doc false
      def __rustq_items__, do: [unquote(Macro.escape(item))]

      @doc false
      def __rustq_source__, do: unquote(source)
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

  defmacro defhandlers(opts) when is_list(opts) do
    from_ast = Keyword.fetch!(opts, :from)
    {commands, _binding} = Code.eval_quoted(from_ast, [], __CALLER__)

    asts =
      commands
      |> select_commands(opts)
      |> handler_specs()
      |> Enum.map(fn {name, opts} -> handler_ast(name, opts) end)

    items = Enum.map(asts, &Rust.item(RustQ.Rust.AST.Render.render_item(&1)))
    source = Enum.map_join(asts, "\n\n", &RustQ.Rust.AST.Render.render_item/1)

    quote do
      @doc false
      def __rustq_asts__, do: unquote(Macro.escape(asts))

      @doc false
      def __rustq_items__, do: unquote(Macro.escape(items))

      @doc false
      def __rustq_source__, do: unquote(source)
    end
  end

  defp handler_specs(commands) do
    commands
    |> Enum.flat_map(fn {command_name, spec} ->
      case Keyword.fetch(spec, :handler) do
        {:ok, handler} ->
          handler_spec =
            []
            |> append_if_for_generated(Keyword.get(spec, :args, []) != [], args?: true)
            |> append_if_for_generated(Keyword.get(spec, :opts, []) != [], opts: command_name)
            |> Keyword.put(:impl, String.to_atom("#{handler}_impl"))

          [{handler, handler_spec}]

        :error ->
          []
      end
    end)
    |> Enum.uniq_by(&elem(&1, 0))
    |> Enum.sort_by(&elem(&1, 0))
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

  defp handler_ast(name, opts) do
    impl = Keyword.fetch!(opts, :impl)
    args? = Keyword.get(opts, :args?, false)
    opts_name = Keyword.get(opts, :opts)
    command_arg = if args? or opts_name, do: :command, else: :_command

    %AST.Function{
      name: name,
      args: [
        A.arg(:canvas, A.ref_type(:Canvas)),
        A.arg(command_arg, A.term_type())
      ],
      returns: A.nif_result_type(A.unit_type()),
      body: handler_ast_body(impl, args?, opts_name),
      lifetime: :a
    }
  end

  defp handler_ast_body(impl, args?, opts_name) do
    []
    |> append_if(args?, args_decode_stmt())
    |> append_if(opts_name, opts_decode_stmts(opts_name))
    |> List.flatten()
    |> Kernel.++([impl_call_stmt(impl, args?, opts_name)])
  end

  defp args_decode_stmt do
    %AST.Let{
      pattern: %AST.PatVar{name: :args},
      expr: %AST.Try{
        expr: %AST.MethodCall{
          receiver: %AST.Try{
            expr: %AST.MethodCall{
              receiver: %AST.Var{name: :command},
              method: :map_get,
              args: [%AST.PathCall{path: %AST.Path{parts: [:atoms, :args]}}]
            }
          },
          method: :decode,
          generics: [%AST.TypeVec{inner: A.term_type()}]
        }
      }
    }
  end

  defp opts_decode_stmts(opts_name) do
    decoder = String.to_atom("decode_#{opts_name}_opts")

    [
      %AST.Let{
        pattern: %AST.PatVar{name: :opts},
        expr: %AST.Try{expr: %AST.LocalCall{name: :decode_opts, args: [%AST.Var{name: :command}]}}
      },
      %AST.Let{
        pattern: %AST.PatVar{name: :decoded_opts},
        expr: %AST.Try{
          expr: %AST.PathCall{
            path: %AST.Path{parts: [:generated_opts, decoder]},
            args: [%AST.Ref{expr: %AST.Var{name: :opts}}]
          }
        }
      }
    ]
  end

  defp impl_call_stmt(impl, args?, opts_name) do
    args =
      [%AST.Var{name: :canvas}]
      |> append_if(args?, %AST.Var{name: :args})
      |> append_if(opts_name, %AST.Var{name: :decoded_opts})
      |> append_if(opts_name, %AST.Ref{expr: %AST.Var{name: :opts}})

    %AST.Return{expr: %AST.LocalCall{name: impl, args: args}}
  end

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

  def append_if_for_generated(values, nil, _value), do: values
  def append_if_for_generated(values, false, _value), do: values
  def append_if_for_generated(values, _condition, value), do: Keyword.merge(values, value)

  defp append_if(values, nil, _value), do: values
  defp append_if(values, false, _value), do: values
  defp append_if(values, _condition, value), do: values ++ [value]
end
