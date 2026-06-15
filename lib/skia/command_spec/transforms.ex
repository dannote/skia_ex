defmodule Skia.CommandSpec.Transforms do
  @moduledoc false

  def commands do
    [
      translate: [
        handler: :draw_translate,
        args: [],
        opts: [
          [name: :x, type: :number, required: true],
          [name: :y, type: :number, required: true]
        ],
        native_refs: ["skia_safe::Canvas::translate"]
      ],
      scale: [
        handler: :draw_scale,
        args: [],
        opts: [
          [name: :x, type: :number, required: true],
          [name: :y, type: :number, required: true]
        ],
        native_refs: ["skia_safe::Canvas::scale"]
      ],
      rotate: [
        handler: :draw_rotate,
        args: [],
        opts: [[name: :degrees, type: :number, required: true]],
        native_refs: ["skia_safe::Canvas::rotate"]
      ],
      rotate_at: [
        handler: :draw_rotate_at,
        args: [],
        opts: [
          [name: :degrees, type: :number, required: true],
          [name: :x, type: :number, required: true],
          [name: :y, type: :number, required: true]
        ],
        native_refs: ["skia_safe::Canvas::rotate"]
      ],
      concat: [
        handler: :draw_concat,
        args: [],
        opts: [
          [
            name: :matrix,
            type: {:tuple, [:number, :number, :number, :number, :number, :number]},
            required: true
          ]
        ],
        native_refs: ["skia_safe::Canvas::concat"]
      ]
    ]
  end
end
