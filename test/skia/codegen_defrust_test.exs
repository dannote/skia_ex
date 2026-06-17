defmodule Skia.CodegenDefrustTest do
  use ExUnit.Case, async: true

  alias RustQ.Rust.AST

  test "generated command macros define handler and impl functions" do
    commands = Skia.Codegen.GeneratedCommands.__rustq_asts__()
    names = commands |> Enum.map(& &1.name) |> MapSet.new()

    assert MapSet.equal?(
             names,
             MapSet.new([:draw_save, :draw_save_impl, :draw_restore, :draw_restore_impl])
           )

    assert %AST.Function{
             args: [%AST.FunctionArg{name: :canvas}, %AST.FunctionArg{name: :_command}]
           } = Enum.find(commands, &(&1.name == :draw_save))

    assert %AST.Function{
             body: [%AST.ExprStmt{expr: %AST.MethodCall{method: :save}}, %AST.Return{}]
           } = Enum.find(commands, &(&1.name == :draw_save_impl))
  end

  test "generated command macros include restore impl" do
    commands = Skia.Codegen.GeneratedCommands.__rustq_asts__()

    assert %AST.Function{
             body: [%AST.ExprStmt{expr: %AST.MethodCall{method: :restore}}, %AST.Return{}]
           } =
             Enum.find(commands, &(&1.name == :draw_restore_impl))
  end

  test "generated layer impl module is empty while legacy layer bodies remain in codegen" do
    assert Skia.Codegen.GeneratedLayers.__rustq_asts__() == []
  end

  test "generated handlers use direct Rust paths" do
    handlers = Skia.Codegen.GeneratedHandlers.__rustq_asts__()
    names = handlers |> Enum.map(& &1.name) |> MapSet.new()

    refute MapSet.member?(names, :draw_save)
    refute MapSet.member?(names, :draw_restore)
    assert MapSet.member?(names, :draw_path)

    assert %AST.Function{body: draw_path_body} = Enum.find(handlers, &(&1.name == :draw_path))

    assert Enum.any?(draw_path_body, fn
             %AST.Let{
               pattern: %AST.PatVar{name: :args},
               expr: %AST.Try{
                 expr: %AST.MethodCall{
                   receiver: %AST.Try{
                     expr: %AST.MethodCall{
                       args: [%AST.PathCall{path: %AST.Path{parts: [:atoms, :args]}}]
                     }
                   }
                 }
               }
             } ->
               true

             _other ->
               false
           end)

    assert Enum.any?(draw_path_body, fn
             %AST.Let{
               pattern: %AST.PatVar{name: :decoded_opts},
               expr: %AST.Try{
                 expr: %AST.PathCall{path: %AST.Path{parts: [:generated_opts, :decode_path_opts]}}
               }
             } ->
               true

             _other ->
               false
           end)
  end

  test "transform impls use explicit generated opts Rust types" do
    impls = Skia.Codegen.generated_transform_impl_asts()
    names = impls |> Enum.map(& &1.name) |> MapSet.new()

    assert MapSet.equal?(
             names,
             MapSet.new([:draw_translate_impl, :draw_scale_impl, :draw_rotate_impl])
           )

    assert_transform_impl(impls, :draw_translate_impl, :TranslateOpts, :translate)
    assert_transform_impl(impls, :draw_scale_impl, :ScaleOpts, :scale)

    assert %AST.Function{
             args: [
               %AST.FunctionArg{
                 type: %AST.TypeRef{inner: %AST.TypePath{parts: [:skia_safe, :Canvas]}}
               },
               %AST.FunctionArg{
                 name: :opts,
                 type: %AST.TypePath{parts: [:generated_opts, :RotateOpts], lifetimes: [:a]}
               },
               %AST.FunctionArg{name: :_raw_opts, type: "&[(Atom, Term<'a>)]"}
             ],
             body: [
               %AST.ExprStmt{
                 expr: %AST.MethodCall{
                   method: :rotate,
                   args: [%AST.Field{field: :degrees}, %AST.None{}]
                 }
               },
               %AST.Return{}
             ]
           } = Enum.find(impls, &(&1.name == :draw_rotate_impl))
  end

  defp assert_transform_impl(impls, name, opts_type, method) do
    assert %AST.Function{
             args: [
               %AST.FunctionArg{
                 type: %AST.TypeRef{inner: %AST.TypePath{parts: [:skia_safe, :Canvas]}}
               },
               %AST.FunctionArg{
                 name: :opts,
                 type: %AST.TypePath{parts: [:generated_opts, ^opts_type], lifetimes: [:a]}
               },
               %AST.FunctionArg{name: :_raw_opts, type: "&[(Atom, Term<'a>)]"}
             ],
             body: [%AST.ExprStmt{expr: %AST.MethodCall{method: ^method}}, %AST.Return{}]
           } = Enum.find(impls, &(&1.name == name))
  end
end
