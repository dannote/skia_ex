defmodule Skia.CommandSpec.Shapes do
  @moduledoc false

  alias Skia.CommandSpec.Types, as: T

  def commands do
    [
      background: [
        op: :clear,
        handler: :draw_clear,
        args: [color: T.color()],
        opts: [],
        shape: :clear,
        native_refs: ["skia_safe::Canvas::clear"]
      ],
      rect: [
        handler: :draw_rect,
        args: [],
        defaults: [radius: 0],
        opts: T.rect_opts() ++ [[name: :radius, type: :number]] ++ T.paint_opts(),
        shape: [
          setup: [
            "let rect = Rect::from_xywh(opts.x, opts.y, opts.width, opts.height);",
            "let radius = opts.radius.unwrap_or(0.0);"
          ],
          fill: "draw_rect_shape(surface, rect, radius, &paint);",
          stroke: "draw_rect_shape(surface, rect, radius, &paint);"
        ],
        native_refs: ["skia_safe::Canvas::draw_rect", "skia_safe::Canvas::draw_rrect"]
      ],
      oval: [
        handler: :draw_oval,
        args: [],
        opts: T.rect_opts() ++ T.paint_opts(),
        shape: [
          setup: ["let rect = Rect::from_xywh(opts.x, opts.y, opts.width, opts.height);"],
          fill: "surface.canvas().draw_oval(rect, &paint);",
          stroke: "surface.canvas().draw_oval(rect, &paint);"
        ],
        native_refs: ["skia_safe::Canvas::draw_oval"]
      ],
      arc: [
        handler: :draw_arc,
        args: [],
        defaults: [use_center: false],
        opts:
          T.rect_opts() ++
            [
              [name: :start_degrees, type: :number, required: true],
              [name: :sweep_degrees, type: :number, required: true],
              [name: :use_center, type: :boolean]
            ] ++ T.paint_opts(),
        shape: [
          setup: [
            "let rect = Rect::from_xywh(opts.x, opts.y, opts.width, opts.height);",
            "let use_center = opts.use_center.unwrap_or(false);"
          ],
          fill:
            "surface.canvas().draw_arc(rect, opts.start_degrees, opts.sweep_degrees, use_center, &paint);",
          stroke:
            "surface.canvas().draw_arc(rect, opts.start_degrees, opts.sweep_degrees, use_center, &paint);"
        ],
        native_refs: ["skia_safe::Canvas::draw_arc"]
      ],
      circle: [
        handler: :draw_circle,
        args: [],
        opts:
          [
            [name: :x, type: :number, required: true],
            [name: :y, type: :number, required: true],
            [name: :radius, type: :number, required: true]
          ] ++ T.paint_opts(),
        shape: [
          setup: ["let center = Point::new(opts.x, opts.y);"],
          fill: "surface.canvas().draw_circle(center, opts.radius, &paint);",
          stroke: "surface.canvas().draw_circle(center, opts.radius, &paint);"
        ],
        native_refs: ["skia_safe::Canvas::draw_circle"]
      ],
      line: [
        handler: :draw_line,
        args: [],
        opts: [
          [name: :from, type: {:tuple, [:number, :number]}, required: true],
          [name: :to, type: {:tuple, [:number, :number]}, required: true],
          [name: :stroke, type: T.color(), required: true],
          [name: :stroke_width, type: :number],
          [name: :stroke_cap, type: T.stroke_cap()],
          [name: :stroke_join, type: T.stroke_join()],
          [name: :stroke_miter, type: :number],
          [name: :blend_mode, type: T.blend_mode()]
        ],
        shape: [
          required_stroke: true,
          stroke:
            "surface.canvas().draw_line(point_from_term(opts.from)?, point_from_term(opts.to)?, &paint);"
        ],
        native_refs: ["skia_safe::Canvas::draw_line"]
      ]
    ]
  end
end
