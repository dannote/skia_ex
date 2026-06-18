defmodule Skia.CommandSpec.Images do
  @moduledoc false

  alias Skia.CommandSpec.Types, as: T

  def commands do
    [
      image: [
        handler: :draw_image,
        args: [image: :image],
        opts: [
          [name: :x, type: :number, required: true],
          [name: :y, type: :number, required: true],
          [name: :width, type: :number],
          [name: :height, type: :number],
          [name: :source, type: {:tuple, [:number, :number, :number, :number]}],
          [name: :opacity, type: :number],
          [name: :sampling, type: T.sampling_options()],
          [name: :blend_mode, type: T.blend_mode()]
        ],
        native_refs: [
          "skia_safe::Canvas::draw_image_with_sampling_options",
          "skia_safe::Canvas::draw_image_rect_with_sampling_options"
        ]
      ],
      picture: [
        handler: :draw_picture,
        args: [picture: T.picture()],
        defaults: [x: 0, y: 0],
        opts: [
          [name: :x, type: :number],
          [name: :y, type: :number],
          [name: :opacity, type: :number],
          [name: :blend_mode, type: T.blend_mode()]
        ],
        native_refs: ["skia_safe::Canvas::draw_picture"]
      ]
    ]
  end
end
