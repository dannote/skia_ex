defmodule Skia.CommandSpec.Layers do
  @moduledoc false

  alias Skia.CommandSpec.Types, as: T

  def commands do
    [
      save: [
        handler: :draw_save,
        args: [],
        opts: [],
        layer: [body: [{:call, "surface.canvas()", :save, []}]],
        native_refs: ["skia_safe::Canvas::save"]
      ],
      save_layer: [
        handler: :draw_save_layer,
        args: [],
        defaults: [opacity: 1.0],
        opts: [
          [name: :opacity, type: :number],
          [name: :bounds, type: {:tuple, [:number, :number, :number, :number]}],
          [name: :blend_mode, type: T.blend_mode()],
          [name: :blur, type: :number]
        ],
        layer: [
          setup: [
            {:let, "bounds",
             "match opts.bounds { Some(term) => Some(rect_from_term(term)?), None => None }"},
            {:let_mut, "paint", "Paint::default()"},
            {:call, "paint", :set_alpha,
             ["(opts.opacity.unwrap_or(1.0).clamp(0.0, 1.0) * 255.0).round() as u8"]},
            {:stmt, "apply_blend_mode(&mut paint, raw_opts)?"},
            {:if_let, "Some(sigma)", "opts.blur",
             [
               {:if_let, "Some(filter)",
                "image_filters::blur((sigma, sigma), TileMode::Decal, None, None)",
                [{:call, "paint", :set_image_filter, ["filter"]}]}
             ]},
            {:let_mut, "rec", "SaveLayerRec::default().paint(&paint)"},
            {:if_let, "Some(ref bounds)", "bounds", [{:assign, "rec", "rec.bounds(bounds)"}]}
          ],
          body: [{:call, "surface.canvas()", :save_layer, [{:ref, "rec"}]}]
        ],
        native_refs: ["skia_safe::Canvas::save_layer", "skia_safe::ImageFilter::blur"]
      ],
      restore: [
        handler: :draw_restore,
        args: [],
        opts: [],
        layer: [body: [{:call, "surface.canvas()", :restore, []}]],
        native_refs: ["skia_safe::Canvas::restore"]
      ],
      push_style: [args: [], opts: [[name: :style, type: :term, required: true]]],
      pop_style: [args: [], opts: []]
    ]
  end
end
