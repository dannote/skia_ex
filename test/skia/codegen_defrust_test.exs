defmodule Skia.CodegenDefrustTest do
  use ExUnit.Case, async: true

  alias RustQ.Rust.AST

  test "generated command macros define handler and impl functions" do
    commands = Skia.Codegen.GeneratedCommands.__rustq_asts__()
    names = commands |> Enum.map(& &1.name) |> MapSet.new()

    assert MapSet.equal?(names, MapSet.new([:draw_save, :draw_save_impl]))

    assert %AST.Function{
             args: [%AST.FunctionArg{name: :canvas}, %AST.FunctionArg{name: :_command}]
           } = Enum.find(commands, &(&1.name == :draw_save))

    assert %AST.Function{
             body: [%AST.ExprStmt{expr: %AST.MethodCall{method: :save}}, %AST.Return{}]
           } = Enum.find(commands, &(&1.name == :draw_save_impl))
  end

  test "generated layer impls are real defrust functions" do
    impls = Skia.Codegen.GeneratedLayers.__rustq_asts__()
    names = impls |> Enum.map(& &1.name) |> MapSet.new()

    assert MapSet.equal?(names, MapSet.new([:draw_restore_impl]))

    assert %AST.Function{
             body: [%AST.ExprStmt{expr: %AST.MethodCall{method: :restore}}, %AST.Return{}]
           } =
             Enum.find(impls, &(&1.name == :draw_restore_impl))
  end

  test "generated handlers are real defrust functions" do
    handlers = Skia.Codegen.GeneratedHandlers.__rustq_asts__()
    names = handlers |> Enum.map(& &1.name) |> MapSet.new()

    refute MapSet.member?(names, :draw_save)
    assert MapSet.member?(names, :draw_path)

    assert %AST.Function{body: draw_path_body} = Enum.find(handlers, &(&1.name == :draw_path))

    assert Enum.any?(draw_path_body, fn
             %AST.Let{pattern: %AST.PatVar{name: :args}} -> true
             _other -> false
           end)

    assert Enum.any?(draw_path_body, fn
             %AST.Let{pattern: %AST.PatVar{name: :decoded_opts}} -> true
             _other -> false
           end)
  end
end
