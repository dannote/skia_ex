defmodule Skia.CodegenNativeSchemaTest do
  use ExUnit.Case, async: true

  test "reads skia-safe Canvas methods structurally from Rust source" do
    assert %RustQ.Syn.Method{
             name: "draw_rect",
             visibility: :public,
             docs: ["Draws [`Rect`] rect using clip, [`Matrix`], and [`Paint`] `paint`." | _],
             args: [
               %RustQ.Syn.Arg{
                 name: "self",
                 type: "& self",
                 type_ast: %RustQ.Syn.Type.Ref{inner: %RustQ.Syn.Type.Self{}}
               },
               %RustQ.Syn.Arg{
                 name: "rect",
                 type: "impl AsRef < Rect >",
                 type_ast: %RustQ.Syn.Type.ImplTrait{
                   traits: [
                     %RustQ.Syn.Type.Path{
                       name: "AsRef",
                       args: [%RustQ.Syn.Type.Path{name: "Rect"}]
                     }
                   ]
                 }
               },
               %RustQ.Syn.Arg{
                 name: "paint",
                 type: "& Paint",
                 type_ast: %RustQ.Syn.Type.Ref{inner: %RustQ.Syn.Type.Path{name: "Paint"}}
               }
             ],
             returns: "& Self",
             returns_ast: %RustQ.Syn.Type.Ref{inner: %RustQ.Syn.Type.Self{}}
           } = Skia.Codegen.NativeSchema.method!("Canvas", "draw_rect")
  end
end
