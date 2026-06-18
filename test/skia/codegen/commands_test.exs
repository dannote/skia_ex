defmodule Skia.Codegen.CommandsTest do
  use ExUnit.Case, async: true

  test "native-backed commands carry native refs and Syn descriptors" do
    rect = Skia.Codegen.Commands.fetch!(:rect)

    assert %Skia.Codegen.NativeRef{target: "Canvas", method: "draw_rect"} =
             get_in(rect, [:overlay, :native])

    assert %Skia.Codegen.NativeSchema.Method{target: "Canvas", name: "draw_rect", method: method} =
             Keyword.fetch!(rect, :native)

    assert [
             %RustQ.Syn.Arg{name: "self"},
             %RustQ.Syn.Arg{name: "rect"},
             %RustQ.Syn.Arg{name: "paint"}
           ] =
             method.args
  end

  test "overlay defaults are merged into command metadata" do
    assert Keyword.fetch!(Skia.Codegen.Commands.fetch!(:rect), :defaults) == [radius: 0]

    assert Keyword.fetch!(Skia.Codegen.Commands.fetch!(:clip_path), :defaults) ==
             [antialias: true, fill_rule: :winding, clip_op: :intersect]
  end
end
