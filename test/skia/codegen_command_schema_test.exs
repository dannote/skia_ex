defmodule Skia.CodegenCommandSchemaTest do
  use ExUnit.Case, async: true

  test "derives path command args and opts from declaration typespecs" do
    schema =
      Skia.Codegen.CommandSchema.from_file("lib/skia/codegen/commands/paths.ex")

    assert %{args: [path: :path], opts: path_opts} = command!(schema, :path)

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

    assert %{args: [a: :path, b: :path], opts: path_op_opts} = command!(schema, :path_op)
    assert required_opts(path_op_opts) == [:path_op]
    assert :fill_rule in opt_names(path_op_opts)

    assert %{args: [path: :path], opts: outline_opts} = command!(schema, :path_outline)
    assert required_opts(outline_opts) == [:outline_width]
  end

  defp command!(schema, name),
    do: Enum.find(schema, &(&1.name == name)) || flunk("missing #{name}")

  defp opt_names(opts), do: Enum.map(opts, &Keyword.fetch!(&1, :name))

  defp required_opts(opts) do
    opts
    |> Enum.filter(&Keyword.fetch!(&1, :required))
    |> Enum.map(&Keyword.fetch!(&1, :name))
  end
end
