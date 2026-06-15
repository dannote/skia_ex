defmodule Skia.CommandSpec.Clips do
  @moduledoc false

  alias Skia.CommandSpec.Types, as: T

  def commands do
    [
      clip_rect: [
        handler: :clip_rect,
        args: [],
        defaults: [radius: 0, antialias: true],
        opts:
          T.rect_opts() ++ [[name: :radius, type: :number], [name: :antialias, type: :boolean]],
        native_refs: ["skia_safe::Canvas::clip_rect", "skia_safe::Canvas::clip_rrect"]
      ],
      clip_circle: [
        handler: :clip_circle,
        args: [],
        defaults: [antialias: true],
        opts: [
          [name: :x, type: :number, required: true],
          [name: :y, type: :number, required: true],
          [name: :radius, type: :number, required: true],
          [name: :antialias, type: :boolean]
        ],
        native_refs: ["skia_safe::Canvas::clip_path"]
      ],
      clip_path: [
        handler: :clip_path,
        args: [path: :path],
        defaults: [antialias: true, fill_rule: :winding],
        opts: [[name: :antialias, type: :boolean], [name: :fill_rule, type: T.fill_rule()]],
        native_refs: ["skia_safe::Canvas::clip_path"]
      ]
    ]
  end
end
