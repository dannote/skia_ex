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

  alias RustQ.Meta.Type
  alias RustQ.Rust.AST.Render
  alias RustQ.Rust.AST.TypeBuilder
  alias Skia.Codegen.Enums

  @type command :: %{name: atom(), args: keyword(), opts: [keyword()]}

  @spec from_file(Path.t()) :: [command()]
  def from_file(path), do: path |> RustQ.Spec.declarations() |> from_declarations()

  @spec command_metadata_from_file(Path.t(), String.t()) :: keyword()
  def command_metadata_from_file(path, handler_prefix) do
    path
    |> from_file()
    |> Enum.map(fn command ->
      {command.name,
       [
         handler: RustQ.Atom.identifier!("#{handler_prefix}_#{command.name}"),
         args: command.args,
         opts: command.opts
       ]}
    end)
  end

  @spec from_quoted(Macro.t()) :: [command()]
  def from_quoted(quoted), do: quoted |> RustQ.Spec.declarations() |> from_declarations()

  defp from_declarations(%{aliases: types, specs: specs, defs: defs}) do
    specs
    |> Enum.filter(fn {name, spec_arg_types} ->
      Map.has_key?(defs, name) and is_list(spec_arg_types) and at_least_two?(spec_arg_types)
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

  defp resolve_opts_alias(%Type{kind: :alias, meta: %{target: %Type{} = target}}, aliases) do
    resolve_opts_alias(target, aliases)
  end

  defp resolve_opts_alias(%Type{kind: :alias, meta: %{ast: ast}}, aliases) do
    ast |> spec_type(aliases) |> resolve_opts_alias(aliases)
  end

  defp resolve_opts_alias(type, _aliases), do: type

  defp opts_from_type!(%Type{kind: :struct, meta: %{fields: fields}}) do
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

  defp command_type(%Type{kind: :alias, meta: %{elixir_name: name, target: %Type{} = target}}) do
    target
    |> put_elixir_name(name)
    |> command_type()
  end

  defp command_type(%Type{kind: :alias, meta: %{elixir_name: name, ast: ast}}) do
    ast
    |> RustQ.Spec.type(%{})
    |> put_elixir_name(name)
    |> command_type()
  end

  defp command_type(%Type{kind: :enum, meta: %{enum: enum}} = type) do
    spec = Enums.spec!(enum)
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

  defp command_type(%Type{} = type), do: type

  defp put_elixir_name(%Type{} = type, name),
    do: put_in(type.meta[:elixir_name], name)

  defp at_least_two?([_, _ | _]), do: true
  defp at_least_two?(_items), do: false

  defp rust_type_ast(rust_type), do: TypeBuilder.path(rust_type)

  defp rust_type_string(rust_type),
    do: rust_type |> rust_type_ast() |> Render.render_type() |> IO.iodata_to_binary()
end
