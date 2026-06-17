defmodule Skia.Codegen.Defrust do
  @moduledoc false

  defmacro __using__(_opts) do
    quote do
      import Skia.Codegen.Defrust
      alias RustQ.Type, as: R
    end
  end

  defmacro defhandler(name, opts) do
    handler_definition(name, opts)
  end

  defmacro defhandlers(opts) when is_list(opts) do
    from_ast = Keyword.fetch!(opts, :from)
    {commands, _binding} = Code.eval_quoted(from_ast, [], __CALLER__)

    commands
    |> handler_specs()
    |> Enum.map(fn {name, opts} -> handler_definition(name, opts) end)
    |> then(&{:__block__, [], &1})
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

  defp handler_definition(name, opts) do
    impl = Keyword.fetch!(opts, :impl)
    args? = Keyword.get(opts, :args?, false)
    opts_name = Keyword.get(opts, :opts)
    command_arg = if args? or opts_name, do: :command, else: :_command
    body = handler_body(impl, args?, opts_name)

    quote do
      @spec unquote(name)(R.ref(Canvas.t()), term()) :: R.nif_result(R.unit())
      defrust unquote(name)(canvas, unquote(Macro.var(command_arg, nil))) do
        unquote(body)
      end
    end
  end

  defp handler_body(impl, args?, opts_name) do
    setup =
      []
      |> append_if(args?, args_decode_ast())
      |> append_if(opts_name, opts_decode_ast(opts_name))
      |> List.flatten()

    {:__block__, [], setup ++ [impl_call_ast(impl, args?, opts_name)]}
  end

  defp args_decode_ast do
    quote do
      args = decode_as!(unwrap!(command.map_get(Atoms.args())), R.vec(term()))
    end
  end

  defp opts_decode_ast(opts_name) do
    decoder = String.to_atom("decode_#{opts_name}_opts")

    [
      quote do
        opts = unwrap!(decode_opts(command))
      end,
      {:=, [],
       [
         Macro.var(:decoded_opts, nil),
         {:unwrap!, [],
          [
            {{:., [], [{:__aliases__, [], [:GeneratedOpts]}, decoder]}, [],
             [
               {:ref, [], [Macro.var(:opts, nil)]}
             ]}
          ]}
       ]}
    ]
  end

  defp impl_call_ast(impl, args?, opts_name) do
    args =
      [Macro.var(:canvas, nil)]
      |> append_if(args?, Macro.var(:args, nil))
      |> append_if(opts_name, Macro.var(:decoded_opts, nil))
      |> append_if(opts_name, {:ref, [], [Macro.var(:opts, nil)]})

    {impl, [], args}
  end

  def append_if_for_generated(values, nil, _value), do: values
  def append_if_for_generated(values, false, _value), do: values
  def append_if_for_generated(values, _condition, value), do: Keyword.merge(values, value)

  defp append_if(values, nil, _value), do: values
  defp append_if(values, false, _value), do: values
  defp append_if(values, _condition, value), do: values ++ [value]
end
