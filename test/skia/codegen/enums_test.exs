defmodule Skia.Codegen.EnumsTest do
  use ExUnit.Case, async: true

  test "top-level enum generation delegates to enum module" do
    assert Skia.Codegen.generated_enums() == Skia.Codegen.Enums.generated()
  end

  test "enum metadata includes command option enums and extra native enums" do
    defs = Skia.Codegen.Enums.defs()

    assert Map.has_key?(defs, :blend_mode)
    assert Map.has_key?(defs, :fill_rule)
    assert Map.has_key?(defs, :encoded_image_format)
  end
end
