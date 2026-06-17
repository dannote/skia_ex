defmodule Skia.Codegen.TransformImpls do
  @moduledoc """
  RustQ-backed transform implementation generation.

  Signatures use Skia-owned Rust type paths supplied through `ImplHelpers`; the
  implementation bodies are lowered from valid Elixir via `RustQ.Meta.quoted/2`.
  Keep Skia command semantics here and keep generic Rust syntax support in
  RustQ.
  """

  alias RustQ.Rust.AST
  alias RustQ.Rust.AST.Builder, as: A
  alias Skia.Codegen.ImplHelpers
  alias Skia.CommandSpec.Transforms

  @commands [:translate, :scale, :rotate, :rotate_at, :concat]

  @spec commands() :: [atom()]
  def commands, do: @commands

  @spec generated_asts() :: [AST.Function.t()]
  def generated_asts do
    Transforms.commands()
    |> Keyword.take(@commands)
    |> Enum.map(fn {name, spec} -> generated_ast(name, spec) end)
  end

  defp generated_ast(name, spec) do
    handler = Keyword.fetch!(spec, :handler)

    RustQ.Meta.quoted(String.to_atom("#{handler}_impl"),
      args: ImplHelpers.command_impl_args(name),
      returns: A.nif_result_type(A.unit_type()),
      do: body_ast!(spec)
    )
  end

  defp body_ast!(spec) do
    setup = spec |> get_in([:transform, :setup]) |> List.wrap() |> Enum.map(&setup_ast!/1)

    body =
      case get_in(spec, [:transform, :body]) do
        [{:call, "canvas", method, args}] ->
          [
            {{:., [], [Macro.var(:canvas, nil), method]}, [], Enum.map(args, &arg_ast!/1)},
            :ok
          ]

        other ->
          raise ArgumentError, "unsupported generated transform body: #{inspect(other)}"
      end

    {:__block__, [], setup ++ body}
  end

  defp setup_ast!({:let, "matrix", "matrix_from_term(opts.matrix)?"}) do
    {:=, [],
     [
       Macro.var(:matrix, nil),
       {:unwrap!, [], [{:matrix_from_term, [], [ImplHelpers.opts_field_ast(:matrix)]}]}
     ]}
  end

  defp setup_ast!(other),
    do: raise(ArgumentError, "unsupported generated transform setup: #{inspect(other)}")

  defp arg_ast!({:tuple, fields}), do: {:{}, [], Enum.map(fields, &arg_ast!/1)}

  defp arg_ast!({:some, "Point::new(opts.x, opts.y)"}),
    do:
      {:some, [],
       [
         {{:., [], [{:__aliases__, [], [:Point]}, :new]}, [],
          [ImplHelpers.opts_field_ast(:x), ImplHelpers.opts_field_ast(:y)]}
       ]}

  defp arg_ast!(:none), do: {:none, [], []}
  defp arg_ast!("&matrix"), do: {:ref, [], [Macro.var(:matrix, nil)]}
  defp arg_ast!("opts." <> field), do: ImplHelpers.opts_field_ast(String.to_atom(field))

  defp arg_ast!(other),
    do: raise(ArgumentError, "unsupported generated transform argument: #{inspect(other)}")
end
