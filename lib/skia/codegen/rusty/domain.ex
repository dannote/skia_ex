defmodule Skia.Codegen.Rusty.Domain do
  @moduledoc false

  defmacro __using__(opts) do
    commands_module = opts |> Keyword.fetch!(:from) |> Macro.expand(__CALLER__)
    commands = opts |> Keyword.fetch!(:commands) |> expand_value!(__CALLER__)
    helpers = opts |> Keyword.get(:helpers, []) |> expand_value!(__CALLER__)

    rust_sources =
      opts
      |> Keyword.get(:rust_sources, ["native/skia_native/src/lib.rs"])
      |> expand_value!(__CALLER__)

    callable_modules =
      opts
      |> Keyword.get(:callable_modules, [
        Skia.Codegen.Rusty.PaintSupport,
        Skia.Codegen.Rusty.StyleHelpers
      ])
      |> expand_value!(__CALLER__)

    rust_packages =
      opts
      |> Keyword.get(:rust_packages, [
        {"skia-safe", manifest_path: "native/skia_native/Cargo.toml"}
      ])
      |> expand_value!(__CALLER__)

    handlers = handler_defs(commands_module, only: commands)

    quote do
      use RustQ.Meta,
        rust_sources: unquote(Macro.escape(rust_sources)),
        rust_packages: unquote(Macro.escape(rust_packages)),
        callable_modules: unquote(Macro.escape(callable_modules))

      import Skia.Codegen.Rusty.Domain

      @commands unquote(commands)

      @spec commands() :: [atom()]
      def commands, do: @commands

      @spec generated_asts() :: [RustQ.Rust.AST.Function.t()]
      def generated_asts do
        command_asts =
          unquote(commands_module).commands()
          |> Keyword.take(@commands)
          |> Enum.flat_map(fn {_name, spec} -> generated_asts(spec) end)

        command_asts ++ Enum.map(unquote(helpers), &rust_ast!/1)
      end

      defp generated_asts(spec) do
        handler = Keyword.fetch!(spec, :handler)
        [rust_ast!(handler), impl_ast!(handler)]
      end

      defp impl_ast!(handler) do
        handler
        |> then(&String.to_atom("#{&1}_impl"))
        |> rust_ast!()
      end

      defp rust_ast!(name) do
        Enum.find(__rustq_asts__(), &(&1.name == name)) ||
          raise "missing Rusty command AST #{name}"
      end

      unquote_splicing(handlers)
    end
  end

  defmacro handlers(commands_module, opts \\ []) do
    commands_module = Macro.expand(commands_module, __CALLER__)
    opts = expand_value!(opts, __CALLER__)
    handlers = handler_defs(commands_module, opts)

    quote do
      (unquote_splicing(handlers))
    end
  end

  defp handler_defs(commands_module, opts) do
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
      raise ArgumentError, "expected @#{name} to be set before handlers/2"
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
