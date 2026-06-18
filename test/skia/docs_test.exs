defmodule Skia.DocsTest do
  use ExUnit.Case, async: true

  test "native-backed generated command functions carry Syn-derived Rust docs" do
    {:docs_v1, _anno, :elixir, "text/markdown", _module_doc, _metadata, docs} =
      Code.fetch_docs(Skia)

    rect_doc =
      Enum.find_value(docs, fn
        {{:function, :rect, _arity}, _anno, _signature, %{"en" => doc}, _metadata} -> doc
        _other -> nil
      end)

    assert rect_doc =~ "Adds a `rect` command to the document."
    assert rect_doc =~ "Native `skia_safe::Canvas::draw_rect` docs:"
    assert rect_doc =~ "Draws `Rect` rect using clip, `Matrix`, and `Paint` `paint`."
  end
end
