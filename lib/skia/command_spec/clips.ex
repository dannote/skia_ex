defmodule Skia.CommandSpec.Clips do
  @moduledoc false

  alias Skia.CommandSpec.Types, as: T

  def commands do
    [
      clip_rect: [
        handler: :clip_rect,
        args: [],
        defaults: [radius: 0, antialias: true, clip_op: :intersect],
        opts:
          T.rect_opts() ++
            [
              [name: :radius, type: :number],
              [name: :antialias, type: :boolean],
              [name: :clip_op, type: T.clip_op()]
            ],
        clip: [
          setup: [
            {:let, "rect", "Rect::from_xywh(opts.x, opts.y, opts.width, opts.height)"},
            {:let, "radius", "opts.radius.unwrap_or(0.0)"},
            {:let, "antialias", "opts.antialias.unwrap_or(true)"},
            {:let, "clip_op", "decode_clip_op(opts.clip_op.unwrap_or(atoms::intersect()))?"}
          ],
          body: [
            {:if_else, "radius > 0.0",
             [
               {:call, "surface.canvas()", :clip_rrect,
                ["RRect::new_rect_xy(rect, radius, radius)", "clip_op", "antialias"]}
             ], [{:call, "surface.canvas()", :clip_rect, ["rect", "clip_op", "antialias"]}]}
          ]
        ],
        native_refs: ["skia_safe::Canvas::clip_rect", "skia_safe::Canvas::clip_rrect"]
      ],
      clip_circle: [
        handler: :clip_circle,
        args: [],
        defaults: [antialias: true, clip_op: :intersect],
        opts: [
          [name: :x, type: :number, required: true],
          [name: :y, type: :number, required: true],
          [name: :radius, type: :number, required: true],
          [name: :antialias, type: :boolean],
          [name: :clip_op, type: T.clip_op()]
        ],
        clip: [
          setup: [
            {:let_mut, "builder", "PathBuilder::new()"},
            {:call, "builder", :add_circle, ["Point::new(opts.x, opts.y)", "opts.radius", :none]},
            {:let, "path", "builder.detach()"},
            {:let, "clip_op", "decode_clip_op(opts.clip_op.unwrap_or(atoms::intersect()))?"}
          ],
          body: [
            {:call, "surface.canvas()", :clip_path,
             [{:ref, "path"}, "clip_op", "opts.antialias.unwrap_or(true)"]}
          ]
        ],
        native_refs: ["skia_safe::Canvas::clip_path"]
      ],
      clip_path: [
        handler: :clip_path,
        args: [path: :path],
        defaults: [antialias: true, fill_rule: :winding, clip_op: :intersect],
        opts: [
          [name: :antialias, type: :boolean],
          [name: :fill_rule, type: T.fill_rule()],
          [name: :clip_op, type: T.clip_op()]
        ],
        clip: [
          setup: [
            {:let_mut, "path", "build_path(*args.first().ok_or(rustler::Error::BadArg)?)?"},
            {:stmt, "apply_fill_rule(&mut path, raw_opts)?"},
            {:let, "clip_op", "decode_clip_op(opts.clip_op.unwrap_or(atoms::intersect()))?"}
          ],
          body: [
            {:call, "surface.canvas()", :clip_path,
             [{:ref, "path"}, "clip_op", "opts.antialias.unwrap_or(true)"]}
          ]
        ],
        native_refs: ["skia_safe::Canvas::clip_path"]
      ]
    ]
  end
end
