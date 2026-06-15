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
            {:let_mut, "path", "build_path(*args.first().ok_or(rustler::Error::BadArg)?)?"},
            {:stmt, "apply_fill_rule(&mut path, raw_opts)?"}
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
            {:let, "a", "build_path(*args.first().ok_or(rustler::Error::BadArg)?)?"},
            {:let, "b", "build_path(*args.get(1).ok_or(rustler::Error::BadArg)?)?"},
            {:let, "op", "generated_enums::decode_path_op(opts.path_op)?"},
            {:let_mut, "path", "a.op(&b, op).ok_or(rustler::Error::BadArg)?"},
            {:stmt, "apply_fill_rule(&mut path, raw_opts)?"}
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
            {:let, "path", "build_path(*args.first().ok_or(rustler::Error::BadArg)?)?"},
            {:let_mut, "stroke", "Paint::default()"},
            {:stmt,
             "stroke.set_anti_alias(true).set_style(PaintStyle::Stroke).set_stroke_width(opts.outline_width)"},
            {:stmt, "apply_stroke_options(&mut stroke, raw_opts)?"},
            {:let_mut, "builder", "PathBuilder::new()"},
            {:return_if,
             "!path_utils::fill_path_with_paint(&path, &stroke, &mut builder, None, None)"},
            {:let_mut, "outline", "builder.detach()"},
            {:stmt, "apply_fill_rule(&mut outline, raw_opts)?"}
          ],
          body: [
            {:if_let_else, "Some(fill)", "opts.fill",
             [
               {:let_mut, "paint", "decode_paint(fill)?"},
               {:stmt, "apply_blend_mode(&mut paint, raw_opts)?"},
               {:call, "surface.canvas()", :draw_path, ["&outline", "&paint"]}
             ],
             [
               {:if_let, "Some(stroke_color)", "opts.stroke",
                [
                  {:let_mut, "paint", "fill_paint(decode_color(stroke_color)?)"},
                  {:stmt, "apply_blend_mode(&mut paint, raw_opts)?"},
                  {:call, "surface.canvas()", :draw_path, ["&outline", "&paint"]}
                ]}
             ]}
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
      {:if_let, "Some(fill)", "#{opts_var}.fill",
       [
         {:let_mut, "paint", "decode_paint(fill)?"},
         {:stmt, "apply_blend_mode(&mut paint, raw_opts)?"},
         {:call, "surface.canvas()", :draw_path, ["&#{path_var}", "&paint"]}
       ]},
      {:if_let, "Some(stroke)", "#{opts_var}.stroke",
       [
         {:call, "surface.canvas()", :draw_path,
          [
            "&#{path_var}",
            "&stroke_paint(decode_color(stroke)?, #{opts_var}.stroke_width.unwrap_or(1.0), raw_opts)?"
          ]}
       ]}
    ]
  end
end
