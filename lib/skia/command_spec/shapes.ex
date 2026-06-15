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
        shape_draw: [
          body: [
            {:if_let, "Some(color)", "args.first().and_then(|term| decode_color(*term).ok())",
             [{:call, "canvas", :clear, ["color"]}]}
          ]
        ],
        native_refs: ["skia_safe::Canvas::clear"]
      ],
      rect: [
        handler: :draw_rect,
        args: [],
        defaults: [radius: 0],
        opts: T.rect_opts() ++ [[name: :radius, type: :number]] ++ T.paint_opts(),
        shape_draw: [
          setup: [
            {:let, "rect", "Rect::from_xywh(opts.x, opts.y, opts.width, opts.height)"},
            {:let, "radius", "opts.radius.unwrap_or(0.0)"}
          ],
          body: paint_shape_body({:stmt, "draw_rect_shape(canvas, rect, radius, &paint)"})
        ],
        native_refs: ["skia_safe::Canvas::draw_rect", "skia_safe::Canvas::draw_rrect"]
      ],
      oval: [
        handler: :draw_oval,
        args: [],
        opts: T.rect_opts() ++ T.paint_opts(),
        shape_draw: [
          setup: [{:let, "rect", "Rect::from_xywh(opts.x, opts.y, opts.width, opts.height)"}],
          body: paint_shape_body({:call, "canvas", :draw_oval, ["rect", "&paint"]})
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
        shape_draw: [
          setup: [
            {:let, "rect", "Rect::from_xywh(opts.x, opts.y, opts.width, opts.height)"},
            {:let, "use_center", "opts.use_center.unwrap_or(false)"}
          ],
          body:
            paint_shape_body(
              {:call, "canvas", :draw_arc,
               ["rect", "opts.start_degrees", "opts.sweep_degrees", "use_center", "&paint"]}
            )
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
        shape_draw: [
          setup: [{:let, "center", "Point::new(opts.x, opts.y)"}],
          body:
            paint_shape_body({:call, "canvas", :draw_circle, ["center", "opts.radius", "&paint"]})
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
        shape_draw: [
          body: [
            {:let, "color", "decode_color(opts.stroke)?"},
            {:let, "paint", "stroke_paint(color, opts.stroke_width.unwrap_or(1.0), raw_opts)?"},
            {:call, "canvas", :draw_line,
             ["point_from_term(opts.from)?", "point_from_term(opts.to)?", "&paint"]}
          ]
        ],
        native_refs: ["skia_safe::Canvas::draw_line"]
      ]
    ]
  end

  defp paint_shape_body(draw_call) do
    [
      {:if_let, "Some(mut paint)", "opt_fill_paint(raw_opts, atoms::fill())?",
       [{:stmt, "apply_blend_mode(&mut paint, raw_opts)?"}, draw_call]},
      {:if_let, "Some(color)", "opt_color(raw_opts, atoms::stroke())?",
       [
         {:let, "paint", "stroke_paint(color, opts.stroke_width.unwrap_or(1.0), raw_opts)?"},
         draw_call
       ]}
    ]
  end
end
