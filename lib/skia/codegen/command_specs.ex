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
  def from_file(path), do: path |> RustQ.Spec.declarations() |> from_declarations()

  @spec from_quoted(Macro.t()) :: [command()]
  def from_quoted(quoted), do: quoted |> RustQ.Spec.declarations() |> from_declarations()

  defp from_declarations(%{aliases: types, specs: specs, defs: defs}) do
    specs
    |> Enum.filter(fn {name, spec_arg_types} ->
      Map.has_key?(defs, name) and is_list(spec_arg_types) and length(spec_arg_types) >= 2
    end)
    |> Enum.map(fn {name, spec_arg_types} ->
      def_args = Map.fetch!(defs, name)
      command_from_spec(name, def_args, spec_arg_types, types)
    end)
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
    ast
    |> RustQ.Spec.type(%{})
    |> put_elixir_name(name)
    |> command_type()
  end

  defp command_type(%RustQ.Meta.Type{kind: :enum, meta: %{enum: enum}} = type) do
    spec = Skia.Codegen.Enums.spec!(enum)
    rust_type = Keyword.fetch!(spec, :rust)
    descriptor = Keyword.fetch!(spec, :descriptor)

    %{
      type
      | ast: rust_type_ast(rust_type),
        rust: rust_type_string(rust_type),
        meta:
          Map.merge(type.meta, %{
            native_enum: descriptor,
            rust_type: rust_type
          })
    }
  end

  defp command_type(%RustQ.Meta.Type{} = type), do: type

  defp put_elixir_name(%RustQ.Meta.Type{} = type, name),
    do: put_in(type.meta[:elixir_name], name)

  defp rust_type_ast(rust_type), do: RustQ.Rust.AST.TypeBuilder.path(rust_type)

  defp rust_type_string(rust_type),
    do:
      rust_type |> rust_type_ast() |> RustQ.Rust.AST.Render.render_type() |> IO.iodata_to_binary()
end
