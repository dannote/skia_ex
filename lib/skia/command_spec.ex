defmodule Skia.CommandSpec do
  @moduledoc """
  Source of truth for the curated Elixir drawing API.

  Skia enum variants and Rust doc/native-reference checks are inferred from the
  local `skia-safe`/`skia-bindings` sources by `Skia.Codegen.SkiaSafe`.
  """

  @color :color
  @blend_enum {:enum, :blend_mode, skia: "SkBlendMode", rust: :BlendMode}
  @sampling_enum {:enum, :sampling, skia: "SkFilterMode", rust: :FilterMode}
  @stroke_cap_enum {:enum, :stroke_cap, skia: "SkPaint_Cap", rust: "paint::Cap"}
  @stroke_join_enum {:enum, :stroke_join, skia: "SkPaint_Join", rust: "paint::Join"}
  @fill_rule_enum {:enum, :fill_rule, skia: "SkPathFillType", rust: :PathFillType}
  @path_op_enum {:enum, :path_op, skia: "SkPathOp", rust: :PathOp}

  @paint_opts [
    [name: :fill, type: @color],
    [name: :stroke, type: @color],
    [name: :stroke_width, type: :number],
    [name: :stroke_cap, type: @stroke_cap_enum],
    [name: :stroke_join, type: @stroke_join_enum],
    [name: :stroke_miter, type: :number],
    [name: :blend_mode, type: @blend_enum]
  ]

  @rect_opts [
    [name: :x, type: :number, required: true],
    [name: :y, type: :number, required: true],
    [name: :width, type: :number, required: true],
    [name: :height, type: :number, required: true]
  ]

  @commands [
    background: [
      op: :clear,
      handler: :draw_clear,
      args: [color: @color],
      opts: [],
      native_refs: ["skia_safe::Canvas::clear"]
    ],
    rect: [
      handler: :draw_rect,
      args: [],
      defaults: [radius: 0],
      opts: @rect_opts ++ [[name: :radius, type: :number]] ++ @paint_opts,
      native_refs: ["skia_safe::Canvas::draw_rect", "skia_safe::Canvas::draw_rrect"]
    ],
    oval: [
      handler: :draw_oval,
      args: [],
      opts: @rect_opts ++ @paint_opts,
      native_refs: ["skia_safe::Canvas::draw_oval"]
    ],
    arc: [
      handler: :draw_arc,
      args: [],
      defaults: [use_center: false],
      opts:
        @rect_opts ++
          [
            [name: :start_degrees, type: :number, required: true],
            [name: :sweep_degrees, type: :number, required: true],
            [name: :use_center, type: :boolean]
          ] ++ @paint_opts,
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
        ] ++ @paint_opts,
      native_refs: ["skia_safe::Canvas::draw_circle"]
    ],
    line: [
      handler: :draw_line,
      args: [],
      opts: [
        [name: :from, type: {:tuple, [:number, :number]}, required: true],
        [name: :to, type: {:tuple, [:number, :number]}, required: true],
        [name: :stroke, type: @color, required: true],
        [name: :stroke_width, type: :number],
        [name: :stroke_cap, type: @stroke_cap_enum],
        [name: :stroke_join, type: @stroke_join_enum],
        [name: :stroke_miter, type: :number],
        [name: :blend_mode, type: @blend_enum]
      ],
      native_refs: ["skia_safe::Canvas::draw_line"]
    ],
    text: [
      handler: :draw_text,
      args: [text: :string],
      defaults: [size: 16, fill: :black],
      opts: [
        [name: :x, type: :number, required: true],
        [name: :y, type: :number, required: true],
        [name: :width, type: :number],
        [name: :size, type: :number],
        [name: :fill, type: @color],
        [name: :font, type: :font],
        [name: :weight, type: :integer],
        [name: :align, type: :atom],
        [name: :direction, type: :atom]
      ],
      native_refs: ["skia_safe::Canvas::draw_str", "skia_safe::Font::measure_str"]
    ],
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
        [name: :sampling, type: @sampling_enum],
        [name: :blend_mode, type: @blend_enum]
      ],
      native_refs: [
        "skia_safe::Canvas::draw_image_with_sampling_options",
        "skia_safe::Canvas::draw_image_rect_with_sampling_options"
      ]
    ],
    save: [handler: :draw_save, args: [], opts: [], native_refs: ["skia_safe::Canvas::save"]],
    save_layer: [
      handler: :draw_save_layer,
      args: [],
      defaults: [opacity: 1.0],
      opts: [
        [name: :opacity, type: :number],
        [name: :bounds, type: {:tuple, [:number, :number, :number, :number]}],
        [name: :blend_mode, type: @blend_enum],
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
    translate: [
      handler: :draw_translate,
      args: [],
      opts: [
        [name: :x, type: :number, required: true],
        [name: :y, type: :number, required: true]
      ],
      native_refs: ["skia_safe::Canvas::translate"]
    ],
    scale: [
      handler: :draw_scale,
      args: [],
      opts: [
        [name: :x, type: :number, required: true],
        [name: :y, type: :number, required: true]
      ],
      native_refs: ["skia_safe::Canvas::scale"]
    ],
    rotate: [
      handler: :draw_rotate,
      args: [],
      opts: [[name: :degrees, type: :number, required: true]],
      native_refs: ["skia_safe::Canvas::rotate"]
    ],
    rotate_at: [
      handler: :draw_rotate_at,
      args: [],
      opts: [
        [name: :degrees, type: :number, required: true],
        [name: :x, type: :number, required: true],
        [name: :y, type: :number, required: true]
      ],
      native_refs: ["skia_safe::Canvas::rotate"]
    ],
    concat: [
      handler: :draw_concat,
      args: [],
      opts: [
        [
          name: :matrix,
          type: {:tuple, [:number, :number, :number, :number, :number, :number]},
          required: true
        ]
      ],
      native_refs: ["skia_safe::Canvas::concat"]
    ],
    push_style: [args: [], opts: [[name: :style, type: :term, required: true]]],
    pop_style: [args: [], opts: []],
    path: [
      handler: :draw_path,
      args: [path: :path],
      opts: @paint_opts ++ [[name: :fill_rule, type: @fill_rule_enum]],
      native_refs: ["skia_safe::Canvas::draw_path"]
    ],
    path_op: [
      handler: :draw_path_op,
      args: [a: :path, b: :path],
      opts:
        @paint_opts ++
          [
            [name: :path_op, type: @path_op_enum, required: true],
            [name: :fill_rule, type: @fill_rule_enum]
          ],
      native_refs: ["skia_safe::pathops::op", "skia_safe::Canvas::draw_path"]
    ],
    clip_rect: [
      handler: :clip_rect,
      args: [],
      defaults: [radius: 0, antialias: true],
      opts: @rect_opts ++ [[name: :radius, type: :number], [name: :antialias, type: :boolean]],
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
      opts: [[name: :antialias, type: :boolean], [name: :fill_rule, type: @fill_rule_enum]],
      native_refs: ["skia_safe::Canvas::clip_path"]
    ]
  ]

  @spec all() :: keyword()
  def all, do: @commands

  @spec names() :: [atom()]
  def names, do: Keyword.keys(@commands)

  @spec drawable_names() :: [atom()]
  def drawable_names do
    names() --
      [
        :save,
        :save_layer,
        :restore,
        :translate,
        :scale,
        :rotate,
        :rotate_at,
        :concat,
        :push_style,
        :pop_style
      ]
  end

  @spec fetch!(atom()) :: keyword()
  def fetch!(name), do: Keyword.fetch!(@commands, name)
end
