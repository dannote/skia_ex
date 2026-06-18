defmodule Skia.CodegenNativeSchemaTest do
  use ExUnit.Case, async: true

  test "reads skia-safe Canvas methods structurally from Rust source" do
    assert %RustQ.Syn.Method{
             name: "draw_rect",
             visibility: :public,
             args: [
               %RustQ.Syn.Arg{name: "self", type: "& self"},
               %RustQ.Syn.Arg{name: "rect", type: "impl AsRef < Rect >"},
               %RustQ.Syn.Arg{name: "paint", type: "& Paint"}
             ],
             returns: "& Self"
           } = Skia.Codegen.NativeSchema.method!("Canvas", "draw_rect")
  end
end
