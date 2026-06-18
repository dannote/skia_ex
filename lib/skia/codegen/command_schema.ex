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
    body
    |> block_expressions()
    |> Enum.reduce({%{}, [], %{}}, fn
      {:@, _, [{:type, _, [{:"::", _, [{name, _, _ctx}, type_ast]}]}]}, {types, specs, defs} ->
        {Map.put(types, name, type_ast), specs, defs}

      {:@, _, [{:spec, _, [{:"::", _, [{name, _, arg_types}, _return]}]}]},
      {types, specs, defs} ->
        {types, specs ++ [{name, arg_types}], defs}

      {:def, _, [{name, _, args}, _body]}, {types, specs, defs} ->
        {types, specs, Map.put(defs, name, Enum.map(args || [], &arg_name!/1))}

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

  defp expand_type({name, _, []} = ast, types) when is_atom(name) do
    case Map.fetch(types, name) do
      {:ok, type_ast} -> expand_type(type_ast, types)
      :error -> ast
    end
  end

  defp expand_type(other, _types), do: other

  defp command_type({:blend_mode, _, []}, _types),
    do: {:enum, :blend_mode, skia: "SkBlendMode", rust: :BlendMode}

  defp command_type({:stroke_cap, _, []}, _types),
    do: {:enum, :stroke_cap, skia: "SkPaint_Cap", rust: "paint::Cap"}

  defp command_type({:stroke_join, _, []}, _types),
    do: {:enum, :stroke_join, skia: "SkPaint_Join", rust: "paint::Join"}

  defp command_type({:fill_rule, _, []}, _types),
    do: {:enum, :fill_rule, skia: "SkPathFillType", rust: :PathFillType}

  defp command_type({:path_op, _, []}, _types),
    do: {:enum, :path_op, skia: "SkPathOp", rust: :PathOp}

  defp command_type({:clip_op, _, []}, _types),
    do: {:enum, :clip_op, skia: "SkClipOp", rust: :ClipOp}

  defp command_type({:sampling, _, []}, _types),
    do: {:enum, :sampling, skia: "SkFilterMode", rust: :FilterMode}

  defp command_type({:font, _, []}, _types), do: :font
  defp command_type({:point, _, []}, _types), do: {:tuple, [:number, :number]}
  defp command_type({:bounds, _, []}, _types), do: {:tuple, [:number, :number, :number, :number]}

  defp command_type({:source_rect, _, []}, _types),
    do: {:tuple, [:number, :number, :number, :number]}

  defp command_type({:matrix, _, []}, _types),
    do: {:tuple, [:number, :number, :number, :number, :number, :number]}

  defp command_type(ast, types) do
    ast = expand_type(ast, types)

    case ast do
      {{:., _, [{:__aliases__, _, [:Skia, :Path]}, :t]}, _, []} ->
        :path

      {{:., _, [{:__aliases__, _, [:Skia, :Paint]}, :t]}, _, []} ->
        :paint

      {{:., _, [{:__aliases__, _, [:Skia, :Vertices]}, :t]}, _, []} ->
        :vertices

      {{:., _, [{:__aliases__, _, [:Skia, :Image]}, :t]}, _, []} ->
        :image

      {{:., _, [{:__aliases__, _, [:Skia, :Picture]}, :t]}, _, []} ->
        :picture

      {{:., _, [{:__aliases__, _, [:Skia, :TextBlob]}, :t]}, _, []} ->
        :text_blob

      {{:., _, [{:__aliases__, _, [:Skia, :SamplingOptions]}, :t]}, _, []} ->
        :sampling_options

      {{:., _, [{:__aliases__, _, [:Skia, :ImageFilter]}, :t]}, _, []} ->
        :image_filter

      {{:., _, [{:__aliases__, _, [:Skia, :PathEffect]}, :t]}, _, []} ->
        :path_effect

      {{:., _, [{:__aliases__, _, [:Skia, :ColorFilter]}, :t]}, _, []} ->
        :color_filter

      {{:., _, [{:__aliases__, _, [:Skia, :MaskFilter]}, :t]}, _, []} ->
        :mask_filter

      {{:., _, [{:__aliases__, _, [:Skia, :Command]}, :color]}, _, []} ->
        :color

      {{:., _, [{:__aliases__, _, [:String]}, :t]}, _, []} ->
        :string

      {:number, _, []} ->
        :number

      {:boolean, _, []} ->
        :boolean

      {:integer, _, []} ->
        :integer

      {:atom, _, []} ->
        :atom

      {:string, _, []} ->
        :string

      {:font, _, []} ->
        :font

      {:{}, _, [{:number, _, []}, {:number, _, []}]} ->
        {:tuple, [:number, :number]}

      {:{}, _, [{:number, _, []}, {:number, _, []}, {:number, _, []}, {:number, _, []}]} ->
        {:tuple, [:number, :number, :number, :number]}

      {:{}, _,
       [
         {:number, _, []},
         {:number, _, []},
         {:number, _, []},
         {:number, _, []},
         {:number, _, []},
         {:number, _, []}
       ]} ->
        {:tuple, [:number, :number, :number, :number, :number, :number]}

      _other ->
        :term
    end
  end

  defp block_expressions({:__block__, _, expressions}), do: expressions
  defp block_expressions(expression), do: [expression]
end
