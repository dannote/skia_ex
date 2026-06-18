defmodule Skia.Codegen.HandlerShells do
  @moduledoc """
  Direct RustQ AST generation for Skia handler shells.

  Handler shells are plumbing: decode command args/options with Skia-owned Rust
  helpers such as `atoms::args()` and `generated_opts::decode_*_opts`, then call
  the generated impl. They are intentionally direct AST, not `defrust`, because
  they are repetitive Rustler glue rather than Rusty-Elixir command semantics.
  """

  alias RustQ.Rust.AST
  alias RustQ.Rust.AST.Builder, as: A
  alias RustQ.Rust.AST.TypeBuilder, as: T

  @spec generated_asts(keyword(), keyword()) :: [AST.Function.t()]
  def generated_asts(commands, opts \\ []) do
    commands
    |> select_commands(opts)
    |> handler_specs()
    |> Enum.map(fn {name, opts} -> handler_ast(name, opts) end)
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

  defp select_commands(commands, opts) do
    only = opts |> Keyword.get(:only) |> List.wrap()
    except = opts |> Keyword.get(:except, []) |> List.wrap()

    commands
    |> then(fn commands -> if only == [], do: commands, else: Keyword.take(commands, only) end)
    |> Keyword.drop(except)
  end

  defp handler_ast(name, opts) do
    impl = Keyword.fetch!(opts, :impl)
    args? = Keyword.get(opts, :args?, false)
    opts_name = Keyword.get(opts, :opts)
    command_arg = if args? or opts_name, do: :command, else: :_command

    %AST.Function{
      name: name,
      args: [
        A.arg(:canvas, T.ref(:Canvas)),
        A.arg(command_arg, T.term())
      ],
      returns: T.nif_result(T.unit()),
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
          generics: [T.vec(T.term())]
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

  defp append_if_for_generated(values, false, _value), do: values
  defp append_if_for_generated(values, _condition, value), do: Keyword.merge(values, value)

  defp append_if(values, nil, _value), do: values
  defp append_if(values, false, _value), do: values
  defp append_if(values, _condition, value), do: values ++ [value]
end
