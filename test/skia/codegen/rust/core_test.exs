defmodule Skia.Codegen.Rust.CoreTest do
  use ExUnit.Case, async: true

  test "style helpers infer propagation from narrow skia-safe source metadata" do
    source = Skia.Codegen.Rust.Core.generated_style_helpers()

    assert source =~ "paint.set_blend_mode(generated_enums::decode_blend_mode(atom)?);"
    assert source =~ "paint.set_stroke_cap(generated_enums::decode_stroke_cap(atom)?);"
    assert source =~ "paint.set_stroke_join(generated_enums::decode_stroke_join(atom)?);"
    assert source =~ "path.set_fill_type(generated_enums::decode_fill_rule(atom)?);"
    assert source =~ "apply_paint_effects(paint, opts)?;"
    assert source =~ "Ok(Some(generated_enums::decode_clip_op(value)?))"
  end
end
