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

  @command_enum_specs %{
    blend_mode: [skia: "SkBlendMode", rust: :BlendMode],
    stroke_cap: [skia: "SkPaint_Cap", rust: "paint::Cap"],
    stroke_join: [skia: "SkPaint_Join", rust: "paint::Join"],
    fill_rule: [skia: "SkPathFillType", rust: :PathFillType],
    path_op: [skia: "SkPathOp", rust: :PathOp],
    clip_op: [skia: "SkClipOp", rust: :ClipOp]
  }

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

  defp command_type(%RustQ.Meta.Type{kind: :alias, meta: %{elixir_name: name, ast: ast}} = type) do
    case command_enum_spec(name) do
      {:ok, spec} -> enum_type(type, name, spec)
      :error -> RustQ.Spec.type(ast, %{})
    end
  end

  defp command_type(%RustQ.Meta.Type{kind: :enum, meta: %{elixir_name: name}} = type),
    do: enum_type(type, name, enum_spec(name))

  defp command_type(%RustQ.Meta.Type{} = type), do: type

  defp enum_type(%RustQ.Meta.Type{} = type, name, spec) do
    native_name = Keyword.fetch!(spec, :skia)

    %{
      type
      | kind: :enum,
        meta:
          Map.merge(type.meta, %{
            elixir_name: name,
            native_enum: Skia.Codegen.SkiaSafe.enum_descriptor!(native_name),
            rust_type: Keyword.fetch!(spec, :rust)
          })
    }
  end

  defp command_enum_spec(name), do: Map.fetch(@command_enum_specs, name)

  defp enum_spec(name) do
    case command_enum_spec(name) do
      {:ok, spec} -> spec
      :error -> raise ArgumentError, "missing command enum spec for #{inspect(name)}"
    end
  end
end
