defmodule Skia.Codegen.ApiSchema do
  @moduledoc """
  Derives command metadata from Elixir declarations.

  This is the replacement direction for `Skia.CommandSpec`: real Elixir
  `@type`/`@spec` declarations are the source of truth, and this module reads
  their quoted Elixir AST. It intentionally does not parse rendered Rust source
  and does not use Rust module resolver tables.
  """

  @type command :: %{name: atom(), args: keyword(), opts: [keyword()]}

  @spec from_file(Path.t()) :: [command()]
  def from_file(path) do
    path
    |> File.read!()
    |> Code.string_to_quoted!(file: path)
    |> from_quoted()
  end

  @spec from_quoted(Macro.t()) :: [command()]
  def from_quoted(quoted) do
    {types, specs, defs} = collect_declarations(quoted)

    specs
    |> Enum.map(fn {name, spec_arg_types} ->
      def_args = Map.fetch!(defs, name)
      command_from_spec(name, def_args, spec_arg_types, types)
    end)
    |> Enum.sort_by(& &1.name)
  end

  defp collect_declarations({:defmodule, _meta, [_module, [do: body]]}),
    do: collect_declarations(body)

  defp collect_declarations(body) do
    body
    |> block_expressions()
    |> Enum.reduce({%{}, %{}, %{}}, fn
      {:@, _, [{:type, _, [{:"::", _, [{name, _, _ctx}, type_ast]}]}]}, {types, specs, defs} ->
        {Map.put(types, name, type_ast), specs, defs}

      {:@, _, [{:spec, _, [{:"::", _, [{name, _, arg_types}, _return]}]}]},
      {types, specs, defs} ->
        {types, Map.put(specs, name, arg_types), defs}

      {:def, _, [{name, _, args}, _body]}, {types, specs, defs} ->
        {types, specs, Map.put(defs, name, Enum.map(args, &arg_name!/1))}

      _other, acc ->
        acc
    end)
  end

  defp command_from_spec(name, def_args, spec_arg_types, types) do
    arg_names = def_args |> Enum.drop(1) |> Enum.drop(-1)
    arg_types = spec_arg_types |> Enum.drop(1) |> Enum.drop(-1)
    opts_type = List.last(spec_arg_types)

    %{
      name: name,
      args: Enum.zip(arg_names, Enum.map(arg_types, &command_type(&1, types))),
      opts: opts_type |> expand_type(types) |> opts_from_map_type(types)
    }
  end

  defp arg_name!({name, _, context}) when is_atom(name) and is_atom(context), do: name

  defp arg_name!(other),
    do: raise(ArgumentError, "unsupported command declaration argument #{Macro.to_string(other)}")

  defp opts_from_map_type({:%{}, _, fields}, types) do
    Enum.map(fields, fn {{required, _, [name]}, type_ast}
                        when required in [:required, :optional] ->
      [name: name, type: command_type(type_ast, types), required: required == :required]
    end)
  end

  defp opts_from_map_type(other, _types),
    do: raise(ArgumentError, "expected map option type, got #{Macro.to_string(other)}")

  defp expand_type({name, _, []}, types) when is_atom(name),
    do: Map.get(types, name, {name, [], []})

  defp expand_type(other, _types), do: other

  defp command_type(ast, types) do
    ast = expand_type(ast, types)

    case ast do
      {{:., _, [{:__aliases__, _, [:Skia, :Path]}, :t]}, _, []} -> :path
      {{:., _, [{:__aliases__, _, [:Skia, :Paint]}, :t]}, _, []} -> :paint
      {{:., _, [{:__aliases__, _, [:Skia, :ImageFilter]}, :t]}, _, []} -> :image_filter
      {{:., _, [{:__aliases__, _, [:Skia, :PathEffect]}, :t]}, _, []} -> :path_effect
      {{:., _, [{:__aliases__, _, [:Skia, :ColorFilter]}, :t]}, _, []} -> :color_filter
      {{:., _, [{:__aliases__, _, [:Skia, :MaskFilter]}, :t]}, _, []} -> :mask_filter
      {{:., _, [{:__aliases__, _, [:Skia, :Command]}, :color]}, _, []} -> :color
      {:number, _, []} -> :number
      {:atom, _, []} -> :atom
      {:fill_rule, _, []} -> {:enum, :fill_rule}
      {:path_op, _, []} -> {:enum, :path_op}
      _other -> :term
    end
  end

  defp block_expressions({:__block__, _, expressions}), do: expressions
  defp block_expressions(expression), do: [expression]
end
