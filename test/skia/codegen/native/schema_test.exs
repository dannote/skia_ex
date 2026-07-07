defmodule Skia.Codegen.Native.SchemaTest do
  use ExUnit.Case, async: true

  alias RustQ.Syn
  alias Skia.Codegen.Native.Schema, as: NativeSchema

  test "reads skia-safe Canvas methods structurally from Rust source" do
    assert %Syn.Method{
             name: "draw_rect",
             visibility: :public,
             docs: ["Draws [`Rect`] rect using clip, [`Matrix`], and [`Paint`] `paint`." | _],
             args: [self_arg, rect_arg, paint_arg],
             returns: "& Self",
             returns_ast: %Syn.Type.Ref{inner: %Syn.Type.Self{}}
           } = NativeSchema.method!("Canvas", "draw_rect")

    assert %Syn.Arg{
             name: "self",
             type: "& self",
             type_ast: %Syn.Type.Ref{inner: %Syn.Type.Self{}}
           } =
             self_arg

    assert %Syn.Arg{name: "rect", type: "impl AsRef < Rect >"} = rect_arg
    assert Syn.Type.impl_trait?(rect_arg.type_ast, "AsRef", ["Rect"])

    assert %Syn.Arg{name: "paint", type: "& Paint"} = paint_arg
    assert Syn.Type.ref_to?(paint_arg.type_ast, "Paint")
  end

  test "derives safe enum type names from skia-safe aliases" do
    assert NativeSchema.safe_enum_type!("SkBlendMode") == "BlendMode"
    assert NativeSchema.safe_enum_type!("SkPaint_Cap") == "PaintCap"
    assert NativeSchema.safe_enum_type!("SkPaint_Join") == "PaintJoin"
    assert NativeSchema.safe_enum_type!("SkPathFillType") == "PathFillType"
    assert NativeSchema.safe_enum_type!("SkPathOp") == "PathOp"
    assert NativeSchema.safe_enum_type!("SkFilterMode") == "FilterMode"
  end

  test "indexes native methods across skia-safe source files" do
    assert_method("Canvas", "draw_path")
    assert_method("Canvas", "clip_path")
    assert_method("Canvas", "save_layer")
    assert_method("Path", "op")
    assert_method("ImageFilter", "blur")
  end

  defp assert_method(target, name) do
    assert %Syn.Method{name: ^name, visibility: :public} = NativeSchema.method!(target, name)
  end
end
