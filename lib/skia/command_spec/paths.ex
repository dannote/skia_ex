defmodule Skia.CommandSpec.Paths do
  @moduledoc false

  alias Skia.CommandSpec.Types, as: T

  def commands do
    [
      path: [
        handler: :draw_path,
        args: [path: :path],
        opts: T.paint_opts() ++ [[name: :fill_rule, type: T.fill_rule()]],
        path_draw: [
          setup: [
            "let mut path = build_path(*args.first().ok_or(rustler::Error::BadArg)?)?;",
            "apply_fill_rule(&mut path, raw_opts)?;"
          ],
          body: draw_path_body("path", "opts")
        ],
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
        path_draw: [
          setup: [
            "let a = build_path(*args.first().ok_or(rustler::Error::BadArg)?)?;",
            "let b = build_path(*args.get(1).ok_or(rustler::Error::BadArg)?)?;",
            "let op = generated_enums::decode_path_op(opts.path_op)?;",
            "let mut path = a.op(&b, op).ok_or(rustler::Error::BadArg)?;",
            "apply_fill_rule(&mut path, raw_opts)?;"
          ],
          body: draw_path_body("path", "opts")
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
        path_draw: [
          setup: [
            "let path = build_path(*args.first().ok_or(rustler::Error::BadArg)?)?;",
            "let mut stroke = Paint::default();",
            "stroke.set_anti_alias(true).set_style(PaintStyle::Stroke).set_stroke_width(opts.outline_width);",
            "apply_stroke_options(&mut stroke, raw_opts)?;",
            "let mut builder = PathBuilder::new();",
            "if !path_utils::fill_path_with_paint(&path, &stroke, &mut builder, None, None) { return Ok(()); }",
            "let mut outline = builder.detach();",
            "apply_fill_rule(&mut outline, raw_opts)?;"
          ],
          body: [
            "if let Some(fill) = opts.fill {",
            "    let mut paint = decode_paint(fill)?;",
            "    apply_blend_mode(&mut paint, raw_opts)?;",
            "    surface.canvas().draw_path(&outline, &paint);",
            "} else if let Some(stroke_color) = opts.stroke {",
            "    let mut paint = fill_paint(decode_color(stroke_color)?);",
            "    apply_blend_mode(&mut paint, raw_opts)?;",
            "    surface.canvas().draw_path(&outline, &paint);",
            "}"
          ]
        ],
        native_refs: [
          "skia_safe::path_utils::fill_path_with_paint",
          "skia_safe::Canvas::draw_path"
        ]
      ]
    ]
  end

  defp draw_path_body(path_var, opts_var) do
    [
      "if let Some(fill) = #{opts_var}.fill {",
      "    let mut paint = decode_paint(fill)?;",
      "    apply_blend_mode(&mut paint, raw_opts)?;",
      "    surface.canvas().draw_path(&#{path_var}, &paint);",
      "}",
      "if let Some(stroke) = #{opts_var}.stroke {",
      "    surface.canvas().draw_path(&#{path_var}, &stroke_paint(decode_color(stroke)?, #{opts_var}.stroke_width.unwrap_or(1.0), raw_opts)?);",
      "}"
    ]
  end
end
