defmodule Skia.CommandSpec.Text do
  @moduledoc false

  alias Skia.CommandSpec.Types, as: T

  def commands do
    [
      text_blob: [
        handler: :draw_text_blob,
        args: [blob: T.text_blob()],
        defaults: [fill: :black],
        opts:
          [
            [name: :x, type: :number, required: true],
            [name: :y, type: :number, required: true]
          ] ++ T.paint_opts(),
        native_refs: ["skia_safe::Canvas::draw_text_blob"]
      ],
      text: [
        handler: :draw_text,
        args: [text: :string],
        defaults: [size: 16, fill: :black],
        opts: [
          [name: :x, type: :number, required: true],
          [name: :y, type: :number, required: true],
          [name: :width, type: :number],
          [name: :size, type: :number],
          [name: :fill, type: T.color()],
          [name: :font, type: :font],
          [name: :weight, type: :integer],
          [name: :align, type: :atom],
          [name: :direction, type: :atom],
          [name: :font_family, type: :string],
          [name: :line_height, type: :number],
          [name: :spans, type: :term]
        ],
        native_refs: ["skia_safe::Canvas::draw_str", "skia_safe::Font::measure_str"]
      ]
    ]
  end
end
