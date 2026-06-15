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
        text_draw: [
          setup: [
            {:let, "blob", "text_blob_from_term(*args.first().ok_or(rustler::Error::BadArg)?)?"},
            {:let, "paint",
             "match opts.fill { Some(term) => decode_paint(term)?, None => fill_paint(Color::BLACK) }"},
            {:let_mut, "paint", "paint"},
            {:stmt, "apply_paint_effects(&mut paint, raw_opts)?"}
          ],
          body: [
            {:call, "canvas", :draw_text_blob,
             [{:ref, "blob"}, {:tuple, ["opts.x", "opts.y"]}, {:ref, "paint"}]}
          ]
        ],
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
        text_draw: [
          setup: [
            {:let, "text", "args.first().ok_or(rustler::Error::BadArg)?.decode::<String>()?"},
            {:let, "size", "opts.size.unwrap_or(16.0)"},
            {:let_mut, "font",
             "match opts.font { Some(term) => font_from_term(term, size)?, None => Font::default() }"},
            {:call, "font", :set_size, ["size"]},
            {:let, "paint",
             "match opts.fill { Some(term) => fill_paint(decode_color(term)?), None => fill_paint(Color::BLACK) }"}
          ],
          body: [
            {:if_let_else, "Some(width)", "opts.width",
             [
               {:stmt,
                "draw_paragraph_text(canvas, &text, opts.x, opts.y, width, size, &paint, &opts)?"}
             ],
             [
               {:call, "canvas", :draw_str,
                ["text", {:tuple, ["opts.x", "opts.y"]}, {:ref, "font"}, {:ref, "paint"}]}
             ]}
          ]
        ],
        native_refs: ["skia_safe::Canvas::draw_str", "skia_safe::Font::measure_str"]
      ]
    ]
  end
end
