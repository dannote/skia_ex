defmodule Skia.Codegen.Rusty.Command do
  @moduledoc false

  defmacro __using__(_opts) do
    quote do
      import Skia.Codegen.Rusty.Command
    end
  end

  defmacro defcommand_handlers(commands_module, opts \\ []) do
    commands_module = Macro.expand(commands_module, __CALLER__)
    opts = expand_value!(opts, __CALLER__)

    handlers =
      commands_module.commands()
      |> select_commands(opts)
      |> Enum.map(fn {command_name, spec} ->
        handler = Keyword.fetch!(spec, :handler)
        args? = Keyword.get(spec, :args, []) != []
        opts? = Keyword.get(spec, :opts, []) != []
        impl = String.to_atom("#{handler}_impl")
        decoder = String.to_atom("decode_#{command_name}_opts")

        quote do
          @spec unquote(handler)(RustQ.Type.ref(SkiaSafe.Canvas.t()), RustQ.Type.term()) ::
                  RustQ.Type.nif_result(RustQ.Type.unit())
          unquote(command_body(handler, impl, decoder, args?, opts?))
        end
      end)

    quote do
      (unquote_splicing(handlers))
    end
  end

  defp select_commands(commands, opts) do
    only = opts |> Keyword.get(:only, []) |> List.wrap()
    except = opts |> Keyword.get(:except, []) |> List.wrap()

    commands
    |> then(fn commands -> if only == [], do: commands, else: Keyword.take(commands, only) end)
    |> Keyword.drop(except)
    |> Enum.filter(fn {_name, spec} -> Keyword.has_key?(spec, :handler) end)
  end

  defp expand_value!(value, _env) when is_list(value), do: value

  defp expand_value!({:@, _, [{name, _, _}]}, env) when is_atom(name) do
    Module.get_attribute(env.module, name) ||
      raise ArgumentError, "expected @#{name} to be set before defcommand_handlers/2"
  end

  defp expand_value!(quoted, env) do
    {value, _binding} = Code.eval_quoted(quoted, [], env)
    value
  end

  defp command_body(handler, impl, _decoder, true, false) do
    quote do
      defrust unquote(handler)(canvas, command) do
        args = unwrap!(decode_args(command))
        unquote(impl)(canvas, args)
      end
    end
  end

  defp command_body(handler, impl, decoder, false, true) do
    quote do
      defrust unquote(handler)(canvas, command) do
        opts = unwrap!(decode_opts(command))
        decoded_opts = unwrap!(unquote(generated_opts_call(decoder)))
        unquote(impl)(canvas, decoded_opts, ref(opts))
      end
    end
  end

  defp command_body(handler, impl, decoder, true, true) do
    quote do
      defrust unquote(handler)(canvas, command) do
        args = unwrap!(decode_args(command))
        opts = unwrap!(decode_opts(command))
        decoded_opts = unwrap!(unquote(generated_opts_call(decoder)))
        unquote(impl)(canvas, args, decoded_opts, ref(opts))
      end
    end
  end

  defp command_body(handler, impl, _decoder, false, false) do
    quote do
      defrust unquote(handler)(canvas, _command) do
        unquote(impl)(canvas)
      end
    end
  end

  defp generated_opts_call(decoder) do
    {{:., [], [{:__aliases__, [], [:GeneratedOpts]}, decoder]}, [],
     [{:ref, [], [{:opts, [], nil}]}]}
  end
end
