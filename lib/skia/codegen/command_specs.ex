defmodule Skia.Codegen.CommandSpecs do
  @moduledoc """
  Transitional command metadata extraction from Elixir declaration modules.

  This module reads quoted Elixir `@type`/`@spec` declarations for the current
  command overlay modules. It exists to keep the generator small while Skia
  migrates toward native-backed command metadata from `Skia.Codegen.NativeSchema` and
  `RustQ.Syn`.

  Do not treat these Elixir typespec declarations as the long-term source of
  truth for native Skia signatures. Original `skia-safe` Rust source should win.
  This module intentionally does not parse rendered Rust source and does not use
  Rust module resolver tables.
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
    |> Enum.filter(fn {name, spec_arg_types} ->
      Map.has_key?(defs, name) and is_list(spec_arg_types) and length(spec_arg_types) >= 2
    end)
    |> Enum.map(fn {name, spec_arg_types} ->
      def_args = Map.fetch!(defs, name)
      command_from_spec(name, def_args, spec_arg_types, types)
    end)
  end

  defp collect_declarations({:defmodule, _meta, [_module, [do: body]]}),
    do: collect_declarations(body)

  defp collect_declarations(body) do
    {types, specs, defs} =
      body
      |> block_expressions()
      |> Enum.reduce({[], [], %{}}, fn
        {:@, meta, [{:type, _, [{:"::", _, [_name_ast, _type_ast]} = type_ast]}]},
        {types, specs, defs} ->
          {[{:type, type_ast, meta[:line] || 0} | types], specs, defs}

        {:@, _, [{:spec, _, [{:"::", _, [{name, _, arg_types}, _return]}]}]},
        {types, specs, defs} ->
          {types, specs ++ [{name, arg_types}], defs}

        {:def, _, [{name, _, args}, _body]}, {types, specs, defs} ->
          {types, specs, Map.put(defs, name, Enum.map(args || [], &arg_name!/1))}

        _other, acc ->
          acc
      end)

    {RustQ.Spec.aliases(types), specs, defs}
  end

  defp command_from_spec(name, def_args, spec_arg_types, types) do
    arg_names = def_args |> Enum.drop(1) |> Enum.drop(-1)
    arg_types = spec_arg_types |> Enum.drop(1) |> Enum.drop(-1)
    opts_type = List.last(spec_arg_types)

    %{
      name: name,
      args: Enum.zip(arg_names, Enum.map(arg_types, &command_type(&1, types))),
      opts: opts_type |> spec_type(types) |> resolve_opts_alias(types) |> opts_from_type!()
    }
  end

  defp arg_name!({name, _, context}) when is_atom(name) and is_atom(context), do: name

  defp arg_name!(other),
    do: raise(ArgumentError, "unsupported command declaration argument #{Macro.to_string(other)}")

  defp resolve_opts_alias(%RustQ.Meta.Type{kind: :alias, meta: %{ast: ast}}, aliases) do
    ast |> spec_type(aliases) |> resolve_opts_alias(aliases)
  end

  defp resolve_opts_alias(type, _aliases), do: type

  defp opts_from_type!(%RustQ.Meta.Type{kind: :struct, meta: %{fields: fields}}) do
    Enum.map(fields, fn {name, type, presence} ->
      [name: name, type: command_type(type), required: presence == :required]
    end)
  end

  defp opts_from_type!(type), do: raise("expected command opts map type, got #{inspect(type)}")

  defp spec_type({name, _, []}, aliases) when is_atom(name) do
    Map.get(aliases, {name, 0}) || RustQ.Spec.type({name, [], []}, aliases)
  end

  defp spec_type(ast, aliases), do: RustQ.Spec.type(ast, aliases)

  defp command_type(ast, aliases), do: ast |> spec_type(aliases) |> command_type()

  defp command_type(%RustQ.Meta.Type{kind: :alias, meta: %{elixir_name: name, ast: ast}}) do
    if enum_name?(name),
      do: {:enum, name, enum_spec(name)},
      else: ast |> RustQ.Spec.type(%{}) |> command_type()
  end

  defp command_type(%RustQ.Meta.Type{kind: :enum, meta: %{elixir_name: name}}),
    do: {:enum, name, enum_spec(name)}

  defp command_type(%RustQ.Meta.Type{kind: :tuple, meta: %{elements: elements}}),
    do: {:tuple, Enum.map(elements, &command_type/1)}

  defp command_type(%RustQ.Meta.Type{kind: :term}), do: :term
  defp command_type(%RustQ.Meta.Type{kind: :atom}), do: :atom
  defp command_type(%RustQ.Meta.Type{kind: :bool}), do: :boolean
  defp command_type(%RustQ.Meta.Type{kind: kind}) when kind in [:i64, :u8, :u32], do: :integer
  defp command_type(%RustQ.Meta.Type{kind: kind}) when kind in [:f32, :f64], do: :number

  defp command_type(%RustQ.Meta.Type{rust: rust}) do
    rust
    |> String.trim_trailing("<'a>")
    |> String.split("::")
    |> List.last()
    |> Macro.underscore()
    |> String.to_atom()
  end

  defp enum_spec(name) do
    case Skia.Codegen.EnumSpecs.command_spec(name) do
      {:ok, spec} -> spec
      :error -> raise ArgumentError, "missing command enum spec for #{inspect(name)}"
    end
  end

  defp enum_name?(name), do: match?({:ok, _spec}, Skia.Codegen.EnumSpecs.command_spec(name))

  defp block_expressions({:__block__, _, expressions}), do: expressions
  defp block_expressions(expression), do: [expression]
end
