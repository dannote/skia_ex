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
        clip: [
          setup: [
            "let rect = Rect::from_xywh(opts.x, opts.y, opts.width, opts.height);",
            "let radius = opts.radius.unwrap_or(0.0);",
            "let antialias = opts.antialias.unwrap_or(true);"
          ],
          call:
            "if radius > 0.0 { surface.canvas().clip_rrect(RRect::new_rect_xy(rect, radius, radius), None, antialias); } else { surface.canvas().clip_rect(rect, None, antialias); }"
        ],
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
        clip: [
          setup: [
            "let mut builder = PathBuilder::new();",
            "builder.add_circle(Point::new(opts.x, opts.y), opts.radius, None);",
            "let path = builder.detach();"
          ],
          call: "surface.canvas().clip_path(&path, None, opts.antialias.unwrap_or(true));"
        ],
        native_refs: ["skia_safe::Canvas::clip_path"]
      ],
      clip_path: [
        handler: :clip_path,
        args: [path: :path],
        defaults: [antialias: true, fill_rule: :winding],
        opts: [[name: :antialias, type: :boolean], [name: :fill_rule, type: T.fill_rule()]],
        clip: [
          setup: [
            "let mut path = build_path(*args.first().ok_or(rustler::Error::BadArg)?)?;",
            "apply_fill_rule(&mut path, raw_opts)?;"
          ],
          call: "surface.canvas().clip_path(&path, None, opts.antialias.unwrap_or(true));"
        ],
        native_refs: ["skia_safe::Canvas::clip_path"]
      ]
    ]
  end
end
