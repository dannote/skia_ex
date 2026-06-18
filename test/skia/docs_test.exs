defmodule Skia.DocsTest do
  use ExUnit.Case, async: true

  test "native-backed generated command functions carry Syn-derived Rust docs" do
    docs = skia_docs()

    rect_doc = doc_for(docs, :rect)

    assert rect_doc =~ "Adds a `rect` command to the document."
    refute rect_doc =~ "Elixir options:"
    refute rect_doc =~ "Elixir defaults:"

    assert rect_doc =~
             "Native: `skia_safe::Canvas::draw_rect(self: & self, rect: impl AsRef < Rect >, paint: & Paint) -> & Self`"

    assert rect_doc =~ "Native source: `src/core/canvas.rs:"
    assert rect_doc =~ "Native `skia_safe::Canvas::draw_rect` docs:"
    assert rect_doc =~ "Draws `Rect` rect using clip, `Matrix`, and `Paint` `paint`."
  end

  test "native overlays add docs to more public commands" do
    docs = skia_docs()

    assert doc_for(docs, :oval) =~ "Native `skia_safe::Canvas::draw_oval` docs:"
    assert doc_for(docs, :arc) =~ "Native `skia_safe::Canvas::draw_arc` docs:"
    assert doc_for(docs, :clip_rect) =~ "Native `skia_safe::Canvas::clip_rect` docs:"
    assert doc_for(docs, :text_blob) =~ "Native `skia_safe::Canvas::draw_text_blob` docs:"
  end

  defp skia_docs do
    {:docs_v1, _anno, :elixir, "text/markdown", _module_doc, _metadata, docs} =
      Code.fetch_docs(Skia)

    docs
  end

  defp doc_for(docs, name) do
    Enum.find_value(docs, fn
      {{:function, ^name, _arity}, _anno, _signature, %{"en" => doc}, _metadata} -> doc
      _other -> nil
    end)
  end
end
