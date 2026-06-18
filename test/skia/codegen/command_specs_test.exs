defmodule Skia.Codegen.CommandSpecsTest do
  use ExUnit.Case, async: true

  test "derives path command args and opts from declaration typespecs" do
    schema =
      Skia.Codegen.CommandSpecs.from_file("lib/skia/codegen/commands/paths.ex")

    assert %{args: [path: path_type], opts: path_opts} = command!(schema, :path)
    assert external_type?(path_type, Skia.Path, :t)

    assert opt_names(path_opts) == [
             :paint,
             :fill,
             :stroke,
             :stroke_width,
             :stroke_cap,
             :stroke_join,
             :stroke_miter,
             :blend_mode,
             :image_filter,
             :path_effect,
             :color_filter,
             :mask_filter,
             :fill_rule
           ]

    assert %{args: [a: a_type, b: b_type], opts: path_op_opts} = command!(schema, :path_op)
    assert external_type?(a_type, Skia.Path, :t)
    assert external_type?(b_type, Skia.Path, :t)
    assert required_opts(path_op_opts) == [:path_op]
    assert :fill_rule in opt_names(path_op_opts)
    assert enum_type?(opt_type(path_op_opts, :path_op), :path_op, "SkPathOp")

    assert %{args: [path: outline_path_type], opts: outline_opts} =
             command!(schema, :path_outline)

    assert external_type?(outline_path_type, Skia.Path, :t)
    assert required_opts(outline_opts) == [:outline_width]
  end

  defp command!(schema, name),
    do: Enum.find(schema, &(&1.name == name)) || flunk("missing #{name}")

  defp opt_names(opts), do: Enum.map(opts, &Keyword.fetch!(&1, :name))

  defp opt_type(opts, name),
    do: opts |> Enum.find(&(Keyword.fetch!(&1, :name) == name)) |> Keyword.fetch!(:type)

  defp enum_type?(
         %RustQ.Meta.Type{
           kind: :enum,
           meta: %{elixir_name: name, native_enum: %RustQ.NativeEnumDescriptor{name: native_name}}
         },
         name,
         native_name
       ),
       do: true

  defp enum_type?(_other, _name, _native_name), do: false

  defp external_type?(
         %RustQ.Meta.Type{meta: %{elixir_module: module, elixir_type: type}},
         module,
         type
       ),
       do: true

  defp external_type?(_other, _module, _type), do: false

  defp required_opts(opts) do
    opts
    |> Enum.filter(&Keyword.fetch!(&1, :required))
    |> Enum.map(&Keyword.fetch!(&1, :name))
  end
end
