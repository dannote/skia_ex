defmodule Skia.CommandSpec.Paths do
  @moduledoc false

  alias Skia.CommandSpec.Types, as: T

  def commands do
    [
      path: [
        handler: :draw_path,
        args: [path: :path],
        opts: T.paint_opts() ++ [[name: :fill_rule, type: T.fill_rule()]],
        native_refs: ["skia_safe::Canvas::draw_path"]
      ],
      path_op: [
        handler: :draw_path_op,
        args: [a: :path, b: :path],
        opts:
          T.paint_opts() ++
            [
              [name: :path_op, type: T.path_op(), required: true],
              [name: :fill_rule, type: T.fill_rule()]
            ],
        native_refs: ["skia_safe::Path::op", "skia_safe::Canvas::draw_path"]
      ],
      path_outline: [
        handler: :draw_path_outline,
        args: [path: :path],
        opts:
          T.paint_opts() ++
            [
              [name: :outline_width, type: :number, required: true],
              [name: :fill_rule, type: T.fill_rule()]
            ],
        native_refs: [
          "skia_safe::path_utils::fill_path_with_paint",
          "skia_safe::Canvas::draw_path"
        ]
      ]
    ]
  end
end
