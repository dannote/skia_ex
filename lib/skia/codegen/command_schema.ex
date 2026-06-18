defmodule Skia.Codegen.CommandSchema do
  @moduledoc """
  Transitional command metadata extraction from Elixir declaration modules.

  This module reads quoted Elixir `@type`/`@spec` declarations for the current
  command overlay modules. It exists to keep the generator small while Skia
  migrates toward native-backed schemas from `Skia.Codegen.NativeSchema` and
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
    cond do
      enum_name?(name) -> {:enum, name, enum_spec(name)}
      tuple_alias?(ast) -> {:tuple, tuple_alias_elements(ast)}
      true -> name
    end
  end

  defp command_type(%RustQ.Meta.Type{kind: :enum, meta: %{elixir_name: name}}),
    do: {:enum, name, enum_spec(name)}

  defp command_type(%RustQ.Meta.Type{kind: :tuple, rust: rust}),
    do: {:tuple, tuple_elements(rust)}

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

  defp enum_spec(:blend_mode), do: [skia: "SkBlendMode", rust: :BlendMode]
  defp enum_spec(:stroke_cap), do: [skia: "SkPaint_Cap", rust: "paint::Cap"]
  defp enum_spec(:stroke_join), do: [skia: "SkPaint_Join", rust: "paint::Join"]
  defp enum_spec(:fill_rule), do: [skia: "SkPathFillType", rust: :PathFillType]
  defp enum_spec(:path_op), do: [skia: "SkPathOp", rust: :PathOp]
  defp enum_spec(:clip_op), do: [skia: "SkClipOp", rust: :ClipOp]
  defp enum_spec(:sampling), do: [skia: "SkFilterMode", rust: :FilterMode]

  defp enum_name?(name),
    do:
      name in [:blend_mode, :stroke_cap, :stroke_join, :fill_rule, :path_op, :clip_op, :sampling]

  defp tuple_alias?({:{}, _, _}), do: true

  defp tuple_alias?(ast) when is_tuple(ast) and tuple_size(ast) > 0,
    do: ast |> Tuple.to_list() |> Enum.all?(&tuple_alias_element?/1)

  defp tuple_alias?(_ast), do: false

  defp tuple_alias_elements({:{}, _, elems}), do: Enum.map(elems, &tuple_alias_element/1)

  defp tuple_alias_elements(ast) when is_tuple(ast),
    do: ast |> Tuple.to_list() |> Enum.map(&tuple_alias_element/1)

  defp tuple_alias_element({:number, _, []}), do: :number
  defp tuple_alias_element({:boolean, _, []}), do: :boolean
  defp tuple_alias_element({:integer, _, []}), do: :integer
  defp tuple_alias_element({:atom, _, []}), do: :atom
  defp tuple_alias_element({:string, _, []}), do: :string
  defp tuple_alias_element({:binary, _, []}), do: :string

  defp tuple_alias_element?({name, _, []})
       when name in [:number, :boolean, :integer, :atom, :string, :binary],
       do: true

  defp tuple_alias_element?(_ast), do: false

  defp tuple_elements(rust) do
    rust
    |> String.trim_leading("(")
    |> String.trim_trailing(")")
    |> String.split(",", trim: true)
    |> Enum.map(&rust_scalar_type(String.trim(&1)))
  end

  defp rust_scalar_type("f64"), do: :number
  defp rust_scalar_type("f32"), do: :number
  defp rust_scalar_type("bool"), do: :boolean
  defp rust_scalar_type("i64"), do: :integer
  defp rust_scalar_type("Atom"), do: :atom
  defp rust_scalar_type("String"), do: :string
  defp rust_scalar_type(other), do: other |> Macro.underscore() |> String.to_atom()

  defp block_expressions({:__block__, _, expressions}), do: expressions
  defp block_expressions(expression), do: [expression]
end
