defmodule Skia.CommandSpec.Layers do
  @moduledoc false

  alias Skia.CommandSpec.Types, as: T

  def commands do
    [
      save: [handler: :draw_save, args: [], opts: [], native_refs: ["skia_safe::Canvas::save"]],
      save_layer: [
        handler: :draw_save_layer,
        args: [],
        defaults: [opacity: 1.0],
        opts: [
          [name: :opacity, type: :number],
          [name: :bounds, type: {:tuple, [:number, :number, :number, :number]}],
          [name: :blend_mode, type: T.blend_mode()],
          [name: :blur, type: :number]
        ],
        native_refs: ["skia_safe::Canvas::save_layer", "skia_safe::ImageFilter::blur"]
      ],
      restore: [
        handler: :draw_restore,
        args: [],
        opts: [],
        native_refs: ["skia_safe::Canvas::restore"]
      ],
      push_style: [args: [], opts: [[name: :style, type: :term, required: true]]],
      pop_style: [args: [], opts: []]
    ]
  end
end
