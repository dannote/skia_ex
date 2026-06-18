defmodule Skia.Codegen.CommandsTest do
  use ExUnit.Case, async: true

  test "native-backed commands carry native refs and Syn descriptors" do
    rect = Skia.Codegen.Commands.fetch!(:rect)

    assert %RustQ.NativeRef{package: "skia-safe", target: "Canvas", member: "draw_rect"} =
             get_in(rect, [:overlay, :native])

    assert %RustQ.NativeDescriptor{
             ref: %RustQ.NativeRef{package: "skia-safe", target: "Canvas", member: "draw_rect"},
             method: method,
             source_url: source_url
           } = Keyword.fetch!(rect, :native)

    assert source_url =~ "https://docs.rs/crate/skia-safe/"

    assert [
             %RustQ.Syn.Arg{name: "self"},
             %RustQ.Syn.Arg{name: "rect"},
             %RustQ.Syn.Arg{name: "paint"}
           ] =
             method.args
  end

  test "composite command overlays carry expanded native descriptors without direct native docs" do
    clip_circle = Skia.Codegen.Commands.fetch!(:clip_circle)

    refute Keyword.has_key?(clip_circle, :native)

    assert [%RustQ.NativeDescriptor{ref: %RustQ.NativeRef{target: "Canvas", member: "clip_path"}}] =
             Keyword.fetch!(clip_circle, :expands_to)
  end

  test "overlay defaults are merged into command metadata" do
    assert Keyword.fetch!(Skia.Codegen.Commands.fetch!(:rect), :defaults) == [radius: 0]

    assert Keyword.fetch!(Skia.Codegen.Commands.fetch!(:clip_path), :defaults) ==
             [antialias: true, fill_rule: :winding, clip_op: :intersect]
  end
end
