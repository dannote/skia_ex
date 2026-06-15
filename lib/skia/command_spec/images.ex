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
        image_draw: [
          setup: [
            {:let, "image", "image_from_term(*args.first().ok_or(rustler::Error::BadArg)?)?"},
            {:let_mut, "paint", "Paint::default()"},
            {:call, "paint", :set_anti_alias, ["true"]},
            {:if_let, "Some(opacity)", "opts.opacity",
             [
               {:call, "paint", :set_alpha, ["(opacity.clamp(0.0, 1.0) * 255.0).round() as u8"]}
             ]},
            {:stmt, "apply_blend_mode(&mut paint, raw_opts)?"},
            {:let, "sampling", "opt_sampling(raw_opts, atoms::sampling())?"},
            {:let, "source",
             "match opts.source { Some(term) => Some(rect_from_term(term)?), None => None }"}
          ],
          body: [
            {:match, "(opts.width, opts.height, source)",
             [
               {"(Some(width), Some(height), source)",
                [
                  {:let, "src",
                   "source.as_ref().map(|rect| (rect, skia_safe::canvas::SrcRectConstraint::Strict))"},
                  {:call, "surface.canvas()", :draw_image_rect_with_sampling_options,
                   [
                     "image",
                     "src",
                     "Rect::from_xywh(opts.x, opts.y, width, height)",
                     "sampling",
                     {:ref, "paint"}
                   ]}
                ]},
               {"(_, _, Some(source))",
                [
                  {:call, "surface.canvas()", :draw_image_rect_with_sampling_options,
                   [
                     "image",
                     {:some, "(&source, skia_safe::canvas::SrcRectConstraint::Strict)"},
                     "Rect::from_xywh(opts.x, opts.y, source.width(), source.height())",
                     "sampling",
                     {:ref, "paint"}
                   ]}
                ]},
               {"_",
                [
                  {:call, "surface.canvas()", :draw_image_with_sampling_options,
                   ["image", {:tuple, ["opts.x", "opts.y"]}, "sampling", {:some, {:ref, "paint"}}]}
                ]}
             ]}
          ]
        ],
        native_refs: [
          "skia_safe::Canvas::draw_image_with_sampling_options",
          "skia_safe::Canvas::draw_image_rect_with_sampling_options"
        ]
      ]
    ]
  end
end
