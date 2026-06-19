defmodule Skia.Codegen.NativeSchemaTest do
  use ExUnit.Case, async: true

  test "reads skia-safe Canvas methods structurally from Rust source" do
    assert %RustQ.Syn.Method{
             name: "draw_rect",
             visibility: :public,
             docs: ["Draws [`Rect`] rect using clip, [`Matrix`], and [`Paint`] `paint`." | _],
             args: [self_arg, rect_arg, paint_arg],
             returns: "& Self",
             returns_ast: %RustQ.Syn.Type.Ref{inner: %RustQ.Syn.Type.Self{}}
           } = Skia.Codegen.NativeSchema.method!("Canvas", "draw_rect")

    assert %RustQ.Syn.Arg{
             name: "self",
             type: "& self",
             type_ast: %RustQ.Syn.Type.Ref{inner: %RustQ.Syn.Type.Self{}}
           } =
             self_arg

    assert %RustQ.Syn.Arg{name: "rect", type: "impl AsRef < Rect >"} = rect_arg
    assert RustQ.Syn.Type.impl_trait?(rect_arg.type_ast, "AsRef", ["Rect"])

    assert %RustQ.Syn.Arg{name: "paint", type: "& Paint"} = paint_arg
    assert RustQ.Syn.Type.ref_to?(paint_arg.type_ast, "Paint")
  end

  test "derives safe enum type names from skia-safe aliases" do
    assert Skia.Codegen.NativeSchema.safe_enum_type!("SkBlendMode") == "BlendMode"
    assert Skia.Codegen.NativeSchema.safe_enum_type!("SkPaint_Cap") == "PaintCap"
    assert Skia.Codegen.NativeSchema.safe_enum_type!("SkPaint_Join") == "PaintJoin"
    assert Skia.Codegen.NativeSchema.safe_enum_type!("SkPathFillType") == "PathFillType"
    assert Skia.Codegen.NativeSchema.safe_enum_type!("SkPathOp") == "PathOp"
    assert Skia.Codegen.NativeSchema.safe_enum_type!("SkFilterMode") == "FilterMode"
  end

  test "indexes native methods across skia-safe source files" do
    assert_method("Canvas", "draw_path")
    assert_method("Canvas", "clip_path")
    assert_method("Canvas", "save_layer")
    assert_method("Path", "op")
    assert_method("ImageFilter", "blur")
  end

  defp assert_method(target, name) do
    assert %RustQ.Syn.Method{name: ^name, visibility: :public} =
             Skia.Codegen.NativeSchema.method!(target, name)
  end
end
