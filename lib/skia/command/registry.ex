# ex_dna:disable-for-this-file
defmodule Skia.Command.Registry do
  @moduledoc false
  @commands clear: [
              args: [color: {:external, Skia.Command, :color}],
              opts: [],
              defaults: [],
              doc:
                "Adds a `clear` command to the document.\n\nNative: `skia_safe::Canvas::clear`\n\nNative signature: `fn clear(&self, color: impl Into<Color4f>) -> &Self`\n\nNative source: [`src/core/canvas.rs:1235`](https://docs.rs/crate/skia-safe/0.97.2/source/src/core/canvas.rs#L1235)\n\nNative `skia_safe::Canvas::clear` docs:\nFills clip with color `color` using `BlendMode::Src`.\nThis has the effect of replacing all pixels contained by clip with `color`.\n\n- `color` `Color4f` representing unpremultiplied color."
            ],
            rect: [
              args: [],
              opts: [
                [type: :number, name: :x, required: true],
                [type: :number, name: :y, required: true],
                [type: :number, name: :width, required: true],
                [type: :number, name: :height, required: true],
                [type: :number, name: :radius, required: false],
                [type: {:external, Skia.Paint, :t}, name: :paint, required: false],
                [type: {:external, Skia.Command, :color}, name: :fill, required: false],
                [type: {:external, Skia.Command, :color}, name: :stroke, required: false],
                [type: :number, name: :stroke_width, required: false],
                [type: :enum, name: :stroke_cap, required: false],
                [type: :enum, name: :stroke_join, required: false],
                [type: :number, name: :stroke_miter, required: false],
                [type: :enum, name: :blend_mode, required: false],
                [type: {:external, Skia.ImageFilter, :t}, name: :image_filter, required: false],
                [type: {:external, Skia.PathEffect, :t}, name: :path_effect, required: false],
                [type: {:external, Skia.ColorFilter, :t}, name: :color_filter, required: false],
                [type: {:external, Skia.MaskFilter, :t}, name: :mask_filter, required: false]
              ],
              defaults: [radius: 0],
              doc:
                "Adds a `rect` command to the document.\n\nNative: `skia_safe::Canvas::draw_rect`\n\nNative signature: `fn draw_rect(&self, rect: impl AsRef<Rect>, paint: &Paint) -> &Self`\n\nNative source: [`src/core/canvas.rs:1351`](https://docs.rs/crate/skia-safe/0.97.2/source/src/core/canvas.rs#L1351)\n\nNative `skia_safe::Canvas::draw_rect` docs:\nDraws `Rect` rect using clip, `Matrix`, and `Paint` `paint`.\nIn paint: `paint::Style` determines if rectangle is stroked or filled;\nif stroked, `Paint` stroke width describes the line thickness, and\n`paint::Join` draws the corners rounded or square.\n\n- `rect` rectangle to draw\n- `paint` stroke or fill, blend, color, and so on, used to draw\n\nexample: <https://fiddle.skia.org/c/@Canvas_drawRect>"
            ],
            oval: [
              args: [],
              opts: [
                [type: :number, name: :x, required: true],
                [type: :number, name: :y, required: true],
                [type: :number, name: :width, required: true],
                [type: :number, name: :height, required: true],
                [type: {:external, Skia.Paint, :t}, name: :paint, required: false],
                [type: {:external, Skia.Command, :color}, name: :fill, required: false],
                [type: {:external, Skia.Command, :color}, name: :stroke, required: false],
                [type: :number, name: :stroke_width, required: false],
                [type: :enum, name: :stroke_cap, required: false],
                [type: :enum, name: :stroke_join, required: false],
                [type: :number, name: :stroke_miter, required: false],
                [type: :enum, name: :blend_mode, required: false],
                [type: {:external, Skia.ImageFilter, :t}, name: :image_filter, required: false],
                [type: {:external, Skia.PathEffect, :t}, name: :path_effect, required: false],
                [type: {:external, Skia.ColorFilter, :t}, name: :color_filter, required: false],
                [type: {:external, Skia.MaskFilter, :t}, name: :mask_filter, required: false]
              ],
              defaults: [],
              doc:
                "Adds a `oval` command to the document.\n\nNative: `skia_safe::Canvas::draw_oval`\n\nNative signature: `fn draw_oval(&self, oval: impl AsRef<Rect>, paint: &Paint) -> &Self`\n\nNative source: [`src/core/canvas.rs:1395`](https://docs.rs/crate/skia-safe/0.97.2/source/src/core/canvas.rs#L1395)\n\nNative `skia_safe::Canvas::draw_oval` docs:\nDraws oval oval using clip, `Matrix`, and `Paint`.\nIn `paint`: `paint::Style` determines if oval is stroked or filled;\nif stroked, `Paint` stroke width describes the line thickness.\n\n- `oval` `Rect` bounds of oval\n- `paint` `Paint` stroke or fill, blend, color, and so on, used to draw\n\nexample: <https://fiddle.skia.org/c/@Canvas_drawOval>"
            ],
            arc: [
              args: [],
              opts: [
                [type: :number, name: :x, required: true],
                [type: :number, name: :y, required: true],
                [type: :number, name: :width, required: true],
                [type: :number, name: :height, required: true],
                [type: :number, name: :start_degrees, required: true],
                [type: :number, name: :sweep_degrees, required: true],
                [type: :boolean, name: :use_center, required: false],
                [type: {:external, Skia.Paint, :t}, name: :paint, required: false],
                [type: {:external, Skia.Command, :color}, name: :fill, required: false],
                [type: {:external, Skia.Command, :color}, name: :stroke, required: false],
                [type: :number, name: :stroke_width, required: false],
                [type: :enum, name: :stroke_cap, required: false],
                [type: :enum, name: :stroke_join, required: false],
                [type: :number, name: :stroke_miter, required: false],
                [type: :enum, name: :blend_mode, required: false],
                [type: {:external, Skia.ImageFilter, :t}, name: :image_filter, required: false],
                [type: {:external, Skia.PathEffect, :t}, name: :path_effect, required: false],
                [type: {:external, Skia.ColorFilter, :t}, name: :color_filter, required: false],
                [type: {:external, Skia.MaskFilter, :t}, name: :mask_filter, required: false]
              ],
              defaults: [use_center: false],
              doc:
                "Adds a `arc` command to the document.\n\nNative: `skia_safe::Canvas::draw_arc`\n\nNative signature: `fn draw_arc(&self, oval: impl AsRef<Rect>, start_angle: scalar, sweep_angle: scalar, use_center: bool, paint: &Paint) -> &Self`\n\nNative source: [`src/core/canvas.rs:1492`](https://docs.rs/crate/skia-safe/0.97.2/source/src/core/canvas.rs#L1492)\n\nNative `skia_safe::Canvas::draw_arc` docs:\nDraws arc using clip, `Matrix`, and `Paint` paint.\n\nArc is part of oval bounded by oval, sweeping from `start_angle` to `start_angle` plus\n`sweep_angle`. `start_angle` and `sweep_angle` are in degrees.\n\n`start_angle` of zero places start point at the right middle edge of oval.\nA positive `sweep_angle` places arc end point clockwise from start point;\na negative `sweep_angle` places arc end point counterclockwise from start point.\n`sweep_angle` may exceed 360 degrees, a full circle.\nIf `use_center` is `true`, draw a wedge that includes lines from oval\ncenter to arc end points. If `use_center` is `false`, draw arc between end points.\n\nIf `Rect` oval is empty or `sweep_angle` is zero, nothing is drawn.\n\n- `oval` `Rect` bounds of oval containing arc to draw\n- `start_angle` angle in degrees where arc begins\n- `sweep_angle` sweep angle in degrees; positive is clockwise\n- `use_center` if `true`, include the center of the oval\n- `paint` `Paint` stroke or fill, blend, color, and so on, used to draw"
            ],
            circle: [
              args: [],
              opts: [
                [type: :number, name: :x, required: true],
                [type: :number, name: :y, required: true],
                [type: :number, name: :radius, required: true],
                [type: {:external, Skia.Paint, :t}, name: :paint, required: false],
                [type: {:external, Skia.Command, :color}, name: :fill, required: false],
                [type: {:external, Skia.Command, :color}, name: :stroke, required: false],
                [type: :number, name: :stroke_width, required: false],
                [type: :enum, name: :stroke_cap, required: false],
                [type: :enum, name: :stroke_join, required: false],
                [type: :number, name: :stroke_miter, required: false],
                [type: :enum, name: :blend_mode, required: false],
                [type: {:external, Skia.ImageFilter, :t}, name: :image_filter, required: false],
                [type: {:external, Skia.PathEffect, :t}, name: :path_effect, required: false],
                [type: {:external, Skia.ColorFilter, :t}, name: :color_filter, required: false],
                [type: {:external, Skia.MaskFilter, :t}, name: :mask_filter, required: false]
              ],
              defaults: [],
              doc:
                "Adds a `circle` command to the document.\n\nNative: `skia_safe::Canvas::draw_circle`\n\nNative signature: `fn draw_circle(&self, center: impl Into<Point>, radius: scalar, paint: &Paint) -> &Self`\n\nNative source: [`src/core/canvas.rs:1464`](https://docs.rs/crate/skia-safe/0.97.2/source/src/core/canvas.rs#L1464)\n\nNative `skia_safe::Canvas::draw_circle` docs:\nDraws circle at center with radius using clip, `Matrix`, and `Paint` `paint`.\nIf radius is zero or less, nothing is drawn.\nIn `paint`: `paint::Style` determines if circle is stroked or filled;\nif stroked, `Paint` stroke width describes the line thickness.\n\n- `center` circle center\n- `radius` half the diameter of circle\n- `paint` `Paint` stroke or fill, blend, color, and so on, used to draw"
            ],
            vertices: [
              args: [vertices: {:external, Skia.Vertices, :t}],
              opts: [
                [type: {:external, Skia.Paint, :t}, name: :paint, required: false],
                [type: {:external, Skia.Command, :color}, name: :fill, required: false],
                [type: {:external, Skia.Command, :color}, name: :stroke, required: false],
                [type: :number, name: :stroke_width, required: false],
                [type: :enum, name: :stroke_cap, required: false],
                [type: :enum, name: :stroke_join, required: false],
                [type: :number, name: :stroke_miter, required: false],
                [type: :enum, name: :blend_mode, required: false],
                [type: {:external, Skia.ImageFilter, :t}, name: :image_filter, required: false],
                [type: {:external, Skia.PathEffect, :t}, name: :path_effect, required: false],
                [type: {:external, Skia.ColorFilter, :t}, name: :color_filter, required: false],
                [type: {:external, Skia.MaskFilter, :t}, name: :mask_filter, required: false]
              ],
              defaults: [blend_mode: :src_over],
              doc:
                "Adds a `vertices` command to the document.\n\nNative: `skia_safe::Canvas::draw_vertices`\n\nNative signature: `fn draw_vertices(&self, vertices: &Vertices, mode: BlendMode, paint: &Paint) -> &Self`\n\nNative source: [`src/core/canvas.rs:2009`](https://docs.rs/crate/skia-safe/0.97.2/source/src/core/canvas.rs#L2009)\n\nNative `skia_safe::Canvas::draw_vertices` docs:\nDraws `Vertices` vertices, a triangle mesh, using clip and `Matrix`.\nIf `paint` contains an `Shader` and vertices does not contain tex coords, the shader is\nmapped using the vertices' positions.\n\n`BlendMode` is ignored if `Vertices` does not have colors. Otherwise, it combines\n- the `Shader` if `Paint` contains [`Shader`\n- or the opaque `Paint` color if `Paint` does not contain `Shader`\n\nas the src of the blend and the interpolated vertex colors as the dst.\n\n`MaskFilter`, `PathEffect`, and antialiasing on `Paint` are ignored.\n- `vertices` triangle mesh to draw\n- `mode` combines vertices' colors with `Shader` if present or `Paint` opaque color if\nnot. Ignored if the vertices do not contain color.\n- `paint` specifies the `Shader`, used as `Vertices` texture, and\n`ColorFilter`.\n\nexample: <https://fiddle.skia.org/c/@Canvas_drawVertices>\nexample: <https://fiddle.skia.org/c/@Canvas_drawVertices_2>"
            ],
            line: [
              args: [],
              opts: [
                [type: {:tuple, [:number, :number]}, name: :from, required: true],
                [type: {:tuple, [:number, :number]}, name: :to, required: true],
                [type: {:external, Skia.Command, :color}, name: :stroke, required: true],
                [type: :number, name: :stroke_width, required: false],
                [type: :enum, name: :stroke_cap, required: false],
                [type: :enum, name: :stroke_join, required: false],
                [type: :number, name: :stroke_miter, required: false],
                [type: :enum, name: :blend_mode, required: false]
              ],
              defaults: [],
              doc:
                "Adds a `line` command to the document.\n\nNative: `skia_safe::Canvas::draw_line`\n\nNative signature: `fn draw_line(&self, p1: impl Into<Point>, p2: impl Into<Point>, paint: &Paint) -> &Self`\n\nNative source: [`src/core/canvas.rs:1333`](https://docs.rs/crate/skia-safe/0.97.2/source/src/core/canvas.rs#L1333)\n\nNative `skia_safe::Canvas::draw_line` docs:\nDraws line segment from `p1` to `p2` using clip, `Matrix`, and `Paint` paint.\nIn paint: `Paint` stroke width describes the line thickness;\n`paint::Cap` draws the end rounded or square;\n`paint::Style` is ignored, as if were set to `paint::Style::Stroke`.\n\n- `p1` start of line segment\n- `p2` end of line segment\n- `paint` stroke, blend, color, and so on, used to draw"
            ],
            text_blob: [
              args: [blob: {:external, Skia.TextBlob, :t}],
              opts: [
                [type: :number, name: :x, required: true],
                [type: :number, name: :y, required: true],
                [type: {:external, Skia.Paint, :t}, name: :paint, required: false],
                [type: {:external, Skia.Command, :color}, name: :fill, required: false],
                [type: {:external, Skia.Command, :color}, name: :stroke, required: false],
                [type: :number, name: :stroke_width, required: false],
                [type: :enum, name: :stroke_cap, required: false],
                [type: :enum, name: :stroke_join, required: false],
                [type: :number, name: :stroke_miter, required: false],
                [type: :enum, name: :blend_mode, required: false],
                [type: {:external, Skia.ImageFilter, :t}, name: :image_filter, required: false],
                [type: {:external, Skia.PathEffect, :t}, name: :path_effect, required: false],
                [type: {:external, Skia.ColorFilter, :t}, name: :color_filter, required: false],
                [type: {:external, Skia.MaskFilter, :t}, name: :mask_filter, required: false]
              ],
              defaults: [fill: :black],
              doc:
                "Adds a `text_blob` command to the document.\n\nNative: `skia_safe::Canvas::draw_text_blob`\n\nNative signature: `fn draw_text_blob(&self, blob: impl AsRef<TextBlob>, origin: impl Into<Point>, paint: &Paint) -> &Self`\n\nNative source: [`src/core/canvas.rs:1942`](https://docs.rs/crate/skia-safe/0.97.2/source/src/core/canvas.rs#L1942)\n\nNative `skia_safe::Canvas::draw_text_blob` docs:\nDraws `TextBlob` blob at `(origin.x, origin.y)`, using clip, `Matrix`, and `Paint`\npaint.\n\n`blob` contains glyphs, their positions, and paint attributes specific to text:\n`Typeface`, `Paint` text size, `Paint` text scale x, `Paint` text skew x,\n`Paint` align, `Paint` hinting, anti-alias, `Paint` fake bold, `Paint` font embedded\nbitmaps, `Paint` full hinting spacing, LCD text, `Paint` linear text, and `Paint`\nsubpixel text.\n\n`TextEncoding` must be set to `TextEncoding::GlyphId`.\n\nElements of `paint`: `PathEffect`, `MaskFilter`, `Shader`,\n`ColorFilter`, and `ImageFilter`; apply to blob.\n\n- `blob` glyphs, positions, and their paints' text size, typeface, and so on\n- `origin` horizontal and vertical offset applied to blob\n- `paint` blend, color, stroking, and so on, used to draw"
            ],
            text: [
              args: [text: :string],
              opts: [
                [type: :number, name: :x, required: true],
                [type: :number, name: :y, required: true],
                [type: :number, name: :width, required: false],
                [type: :number, name: :size, required: false],
                [type: {:external, Skia.Command, :color}, name: :fill, required: false],
                [type: :term, name: :font, required: false],
                [type: :integer, name: :weight, required: false],
                [type: :atom, name: :align, required: false],
                [type: :atom, name: :direction, required: false],
                [type: :string, name: :font_family, required: false],
                [type: :number, name: :line_height, required: false],
                [type: :term, name: :spans, required: false]
              ],
              defaults: [size: 16, fill: :black],
              doc: "Adds a `text` command to the document."
            ],
            image: [
              args: [image: {:external, Skia.Image, :t}],
              opts: [
                [type: :number, name: :x, required: true],
                [type: :number, name: :y, required: true],
                [type: :number, name: :width, required: false],
                [type: :number, name: :height, required: false],
                [
                  type: {:tuple, [:number, :number, :number, :number]},
                  name: :source,
                  required: false
                ],
                [type: :number, name: :opacity, required: false],
                [type: {:external, Skia.SamplingOptions, :t}, name: :sampling, required: false],
                [type: :enum, name: :blend_mode, required: false]
              ],
              defaults: [],
              doc:
                "Adds a `image` command to the document.\n\nNative: `skia_safe::Canvas::draw_image_with_sampling_options`\n\nNative signature: `fn draw_image_with_sampling_options(&self, image: impl AsRef<Image>, left_top: impl Into<Point>, sampling: impl Into<SamplingOptions>, paint: Option<&Paint>) -> &Self`\n\nNative source: [`src/core/canvas.rs:1613`](https://docs.rs/crate/skia-safe/0.97.2/source/src/core/canvas.rs#L1613)"
            ],
            picture: [
              args: [picture: {:external, Skia.Picture, :t}],
              opts: [
                [type: :number, name: :x, required: false],
                [type: :number, name: :y, required: false],
                [type: :number, name: :opacity, required: false],
                [type: :enum, name: :blend_mode, required: false]
              ],
              defaults: [x: 0, y: 0],
              doc:
                "Adds a `picture` command to the document.\n\nNative: `skia_safe::Canvas::draw_picture`\n\nNative signature: `fn draw_picture(&self, picture: impl AsRef<Picture>, matrix: Option<&Matrix>, paint: Option<&Paint>) -> &Self`\n\nNative source: [`src/core/canvas.rs:1973`](https://docs.rs/crate/skia-safe/0.97.2/source/src/core/canvas.rs#L1973)\n\nNative `skia_safe::Canvas::draw_picture` docs:\nDraws `Picture` picture, using clip and `Matrix`; transforming picture with\n`Matrix` matrix, if provided; and use `Paint` `paint` alpha, `ColorFilter`,\n`ImageFilter`, and `BlendMode`, if provided.\n\nIf paint is not `None`, then the picture is always drawn into a temporary layer before\nactually landing on the canvas. Note that drawing into a layer can also change its\nappearance if there are any non-associative blend modes inside any of the pictures elements.\n\n- `picture` recorded drawing commands to play\n- `matrix` `Matrix` to rotate, scale, translate, and so on; may be `None`\n- `paint` `Paint` to apply transparency, filtering, and so on; may be `None`"
            ],
            save: [
              args: [],
              opts: [],
              defaults: [],
              doc:
                "Adds a `save` command to the document.\n\nNative: `skia_safe::Canvas::save`\n\nNative signature: `fn save(&mut self)`\n\nNative source: [`examples/hello/canvas.rs:28`](https://docs.rs/crate/skia-safe/0.97.2/source/examples/hello/canvas.rs#L28)"
            ],
            save_layer: [
              args: [],
              opts: [
                [type: :number, name: :opacity, required: false],
                [
                  type: {:tuple, [:number, :number, :number, :number]},
                  name: :bounds,
                  required: false
                ],
                [type: :enum, name: :blend_mode, required: false],
                [type: :number, name: :blur, required: false],
                [type: {:external, Skia.ImageFilter, :t}, name: :image_filter, required: false]
              ],
              defaults: [opacity: 1.0],
              doc:
                "Adds a `save_layer` command to the document.\n\nNative: `skia_safe::Canvas::save_layer`\n\nNative signature: `fn save_layer(&self, layer_rec: &SaveLayerRec) -> usize`\n\nNative source: [`src/core/canvas.rs:914`](https://docs.rs/crate/skia-safe/0.97.2/source/src/core/canvas.rs#L914)\n\nNative `skia_safe::Canvas::save_layer` docs:\nSaves `Matrix` and clip, and allocates `Surface` for subsequent drawing.\n\nCalling `Self::restore()` discards changes to `Matrix` and clip,\nand blends `Surface` with alpha opacity onto the prior layer.\n\n`Matrix` may be changed by `Self::translate()`, `Self::scale()`, `Self::rotate()`,\n`Self::skew()`, `Self::concat()`, `Self::set_matrix()`, and `Self::reset_matrix()`.\nClip may be changed by `Self::clip_rect()`, `Self::clip_rrect()`, `Self::clip_path()`,\n`Self::clip_region()`.\n\n`SaveLayerRec` contains the state used to create the layer.\n\nCall `Self::restore_to_count()` with result to restore this and subsequent saves.\n\n- `layer_rec` layer state\n\nReturns depth of save state stack before this call was made.\n\nexample: <https://fiddle.skia.org/c/@Canvas_saveLayer_3>"
            ],
            restore: [
              args: [],
              opts: [],
              defaults: [],
              doc:
                "Adds a `restore` command to the document.\n\nNative: `skia_safe::Canvas::restore`\n\nNative signature: `fn restore(&self) -> &Self`\n\nNative source: [`src/core/canvas.rs:928`](https://docs.rs/crate/skia-safe/0.97.2/source/src/core/canvas.rs#L928)\n\nNative `skia_safe::Canvas::restore` docs:\nRemoves changes to `Matrix` and clip since `Canvas` state was\nlast saved. The state is removed from the stack.\n\nDoes nothing if the stack is empty.\n\nexample: <https://fiddle.skia.org/c/@AutoCanvasRestore_restore>\n\nexample: <https://fiddle.skia.org/c/@Canvas_restore>"
            ],
            push_style: [
              args: [],
              opts: [[type: :term, name: :style, required: true]],
              defaults: [],
              doc: "Adds a `push_style` command to the document."
            ],
            pop_style: [
              args: [],
              opts: [],
              defaults: [],
              doc: "Adds a `pop_style` command to the document."
            ],
            translate: [
              args: [],
              opts: [
                [type: :number, name: :x, required: true],
                [type: :number, name: :y, required: true]
              ],
              defaults: [],
              doc:
                "Adds a `translate` command to the document.\n\nNative: `skia_safe::Canvas::translate`\n\nNative signature: `fn translate(&mut self, dx: f32, dy: f32)`\n\nNative source: [`examples/hello/canvas.rs:33`](https://docs.rs/crate/skia-safe/0.97.2/source/examples/hello/canvas.rs#L33)"
            ],
            scale: [
              args: [],
              opts: [
                [type: :number, name: :x, required: true],
                [type: :number, name: :y, required: true]
              ],
              defaults: [],
              doc:
                "Adds a `scale` command to the document.\n\nNative: `skia_safe::Canvas::scale`\n\nNative signature: `fn scale(&mut self, sx: f32, sy: f32)`\n\nNative source: [`examples/hello/canvas.rs:38`](https://docs.rs/crate/skia-safe/0.97.2/source/examples/hello/canvas.rs#L38)"
            ],
            rotate: [
              args: [],
              opts: [[type: :number, name: :degrees, required: true]],
              defaults: [],
              doc:
                "Adds a `rotate` command to the document.\n\nNative: `skia_safe::Canvas::rotate`\n\nNative signature: `fn rotate(&self, degrees: scalar, p: Option<Point>) -> &Self`\n\nNative source: [`src/core/canvas.rs:1008`](https://docs.rs/crate/skia-safe/0.97.2/source/src/core/canvas.rs#L1008)\n\nNative `skia_safe::Canvas::rotate` docs:\nRotates `Matrix` by degrees about a point at `(p.x, p.y)`. Positive degrees rotates\nclockwise.\n\nMathematically, constructs a rotation matrix; premultiplies the rotation matrix by a\ntranslation matrix; then replaces `Matrix` with the resulting matrix premultiplied with\n`Matrix`.\n\nThis has the effect of rotating the drawing about a given point before transforming the\nresult with `Matrix`.\n\n- `degrees` amount to rotate, in degrees\n- `p` the point to rotate about\n\nexample: <https://fiddle.skia.org/c/@Canvas_rotate_2>"
            ],
            rotate_at: [
              args: [],
              opts: [
                [type: :number, name: :degrees, required: true],
                [type: :number, name: :x, required: true],
                [type: :number, name: :y, required: true]
              ],
              defaults: [],
              doc:
                "Adds a `rotate_at` command to the document.\n\nNative: `skia_safe::Canvas::rotate`\n\nNative signature: `fn rotate(&self, degrees: scalar, p: Option<Point>) -> &Self`\n\nNative source: [`src/core/canvas.rs:1008`](https://docs.rs/crate/skia-safe/0.97.2/source/src/core/canvas.rs#L1008)\n\nNative `skia_safe::Canvas::rotate` docs:\nRotates `Matrix` by degrees about a point at `(p.x, p.y)`. Positive degrees rotates\nclockwise.\n\nMathematically, constructs a rotation matrix; premultiplies the rotation matrix by a\ntranslation matrix; then replaces `Matrix` with the resulting matrix premultiplied with\n`Matrix`.\n\nThis has the effect of rotating the drawing about a given point before transforming the\nresult with `Matrix`.\n\n- `degrees` amount to rotate, in degrees\n- `p` the point to rotate about\n\nexample: <https://fiddle.skia.org/c/@Canvas_rotate_2>"
            ],
            concat: [
              args: [],
              opts: [
                [
                  type: {:tuple, [:number, :number, :number, :number, :number, :number]},
                  name: :matrix,
                  required: true
                ]
              ],
              defaults: [],
              doc:
                "Adds a `concat` command to the document.\n\nNative: `skia_safe::Canvas::concat`\n\nNative signature: `fn concat(&self, matrix: &Matrix) -> &Self`\n\nNative source: [`src/core/canvas.rs:1044`](https://docs.rs/crate/skia-safe/0.97.2/source/src/core/canvas.rs#L1044)\n\nNative `skia_safe::Canvas::concat` docs:\nReplaces `Matrix` with matrix premultiplied with existing `Matrix`.\n\nThis has the effect of transforming the drawn geometry by matrix, before transforming the\nresult with existing `Matrix`.\n\n- `matrix` matrix to premultiply with existing `Matrix`\n\nexample: <https://fiddle.skia.org/c/@Canvas_concat>"
            ],
            path: [
              args: [path: {:external, Skia.Path, :t}],
              opts: [
                [type: {:external, Skia.Paint, :t}, name: :paint, required: false],
                [type: {:external, Skia.Command, :color}, name: :fill, required: false],
                [type: {:external, Skia.Command, :color}, name: :stroke, required: false],
                [type: :number, name: :stroke_width, required: false],
                [type: :enum, name: :stroke_cap, required: false],
                [type: :enum, name: :stroke_join, required: false],
                [type: :number, name: :stroke_miter, required: false],
                [type: :enum, name: :blend_mode, required: false],
                [type: {:external, Skia.ImageFilter, :t}, name: :image_filter, required: false],
                [type: {:external, Skia.PathEffect, :t}, name: :path_effect, required: false],
                [type: {:external, Skia.ColorFilter, :t}, name: :color_filter, required: false],
                [type: {:external, Skia.MaskFilter, :t}, name: :mask_filter, required: false],
                [type: :enum, name: :fill_rule, required: false]
              ],
              defaults: [],
              doc:
                "Adds a `path` command to the document.\n\nNative: `skia_safe::Canvas::draw_path`\n\nNative signature: `fn draw_path(&self, path: &Path, paint: &Paint) -> &Self`\n\nNative source: [`src/core/canvas.rs:1582`](https://docs.rs/crate/skia-safe/0.97.2/source/src/core/canvas.rs#L1582)\n\nNative `skia_safe::Canvas::draw_path` docs:\nDraws `Path` path using clip, `Matrix`, and `Paint` `paint`.\n`Path` contains an array of path contour, each of which may be open or closed.\n\nIn `paint`: `paint::Style` determines if `RRect` is stroked or filled:\nif filled, `PathFillType` determines whether path contour describes inside or\noutside of fill; if stroked, `Paint` stroke width describes the line thickness,\n`paint::Cap` describes line ends, and `paint::Join` describes how\ncorners are drawn.\n\n- `path` `Path` to draw\n- `paint` stroke, blend, color, and so on, used to draw\n\nexample: <https://fiddle.skia.org/c/@Canvas_drawPath>"
            ],
            path_op: [
              args: [a: {:external, Skia.Path, :t}, b: {:external, Skia.Path, :t}],
              opts: [
                [type: {:external, Skia.Paint, :t}, name: :paint, required: false],
                [type: {:external, Skia.Command, :color}, name: :fill, required: false],
                [type: {:external, Skia.Command, :color}, name: :stroke, required: false],
                [type: :number, name: :stroke_width, required: false],
                [type: :enum, name: :stroke_cap, required: false],
                [type: :enum, name: :stroke_join, required: false],
                [type: :number, name: :stroke_miter, required: false],
                [type: :enum, name: :blend_mode, required: false],
                [type: {:external, Skia.ImageFilter, :t}, name: :image_filter, required: false],
                [type: {:external, Skia.PathEffect, :t}, name: :path_effect, required: false],
                [type: {:external, Skia.ColorFilter, :t}, name: :color_filter, required: false],
                [type: {:external, Skia.MaskFilter, :t}, name: :mask_filter, required: false],
                [type: :enum, name: :path_op, required: true],
                [type: :enum, name: :fill_rule, required: false]
              ],
              defaults: [],
              doc: "Adds a `path_op` command to the document."
            ],
            path_outline: [
              args: [path: {:external, Skia.Path, :t}],
              opts: [
                [type: {:external, Skia.Paint, :t}, name: :paint, required: false],
                [type: {:external, Skia.Command, :color}, name: :fill, required: false],
                [type: {:external, Skia.Command, :color}, name: :stroke, required: false],
                [type: :number, name: :stroke_width, required: false],
                [type: :enum, name: :stroke_cap, required: false],
                [type: :enum, name: :stroke_join, required: false],
                [type: :number, name: :stroke_miter, required: false],
                [type: :enum, name: :blend_mode, required: false],
                [type: {:external, Skia.ImageFilter, :t}, name: :image_filter, required: false],
                [type: {:external, Skia.PathEffect, :t}, name: :path_effect, required: false],
                [type: {:external, Skia.ColorFilter, :t}, name: :color_filter, required: false],
                [type: {:external, Skia.MaskFilter, :t}, name: :mask_filter, required: false],
                [type: :number, name: :outline_width, required: true],
                [type: :enum, name: :fill_rule, required: false]
              ],
              defaults: [],
              doc: "Adds a `path_outline` command to the document."
            ],
            clip_rect: [
              args: [],
              opts: [
                [type: :number, name: :x, required: true],
                [type: :number, name: :y, required: true],
                [type: :number, name: :width, required: true],
                [type: :number, name: :height, required: true],
                [type: :number, name: :radius, required: false],
                [type: :boolean, name: :antialias, required: false],
                [type: :enum, name: :clip_op, required: false]
              ],
              defaults: [radius: 0, antialias: true, clip_op: :intersect],
              doc:
                "Adds a `clip_rect` command to the document.\n\nNative: `skia_safe::Canvas::clip_rect`\n\nNative signature: `fn clip_rect(&self, rect: impl AsRef<Rect>, op: impl Into<Option<ClipOp>>, do_anti_alias: impl Into<Option<bool>>) -> &Self`\n\nNative source: [`src/core/canvas.rs:1083`](https://docs.rs/crate/skia-safe/0.97.2/source/src/core/canvas.rs#L1083)\n\nNative `skia_safe::Canvas::clip_rect` docs:\nReplaces clip with the intersection or difference of clip and `rect`,\nwith an aliased or anti-aliased clip edge. `rect` is transformed by `Matrix`\nbefore it is combined with clip.\n\n- `rect` `Rect` to combine with clip\n- `op` `ClipOp` to apply to clip\n- `do_anti_alias` `true` if clip is to be anti-aliased\n\nexample: <https://fiddle.skia.org/c/@Canvas_clipRect>"
            ],
            clip_circle: [
              args: [],
              opts: [
                [type: :number, name: :x, required: true],
                [type: :number, name: :y, required: true],
                [type: :number, name: :radius, required: true],
                [type: :boolean, name: :antialias, required: false],
                [type: :enum, name: :clip_op, required: false]
              ],
              defaults: [antialias: true, clip_op: :intersect],
              doc:
                "Adds a `clip_circle` command to the document.\n\nImplemented via native calls: `skia_safe::Canvas::clip_path`"
            ],
            clip_path: [
              args: [path: {:external, Skia.Path, :t}],
              opts: [
                [type: :boolean, name: :antialias, required: false],
                [type: :enum, name: :fill_rule, required: false],
                [type: :enum, name: :clip_op, required: false]
              ],
              defaults: [antialias: true, fill_rule: :winding, clip_op: :intersect],
              doc:
                "Adds a `clip_path` command to the document.\n\nNative: `skia_safe::Canvas::clip_path`\n\nNative signature: `fn clip_path(&self, path: &Path, op: impl Into<Option<ClipOp>>, do_anti_alias: impl Into<Option<bool>>) -> &Self`\n\nNative source: [`src/core/canvas.rs:1141`](https://docs.rs/crate/skia-safe/0.97.2/source/src/core/canvas.rs#L1141)\n\nNative `skia_safe::Canvas::clip_path` docs:\nReplaces clip with the intersection or difference of clip and `path`,\nwith an aliased or anti-aliased clip edge. `PathFillType` determines if `path`\ndescribes the area inside or outside its contours; and if path contour overlaps\nitself or another path contour, whether the overlaps form part of the area.\n`path` is transformed by `Matrix` before it is combined with clip.\n\n- `path` `Path` to combine with clip\n- `op` `ClipOp` to apply to clip\n- `do_anti_alias` `true` if clip is to be anti-aliased\n\nexample: <https://fiddle.skia.org/c/@Canvas_clipPath>"
            ]
  @non_drawable ~w(save save_layer restore translate scale rotate rotate_at concat push_style pop_style)a
  @spec all() :: keyword()
  def all do
    @commands
  end

  @spec names() :: [atom()]
  def names do
    Keyword.keys(@commands)
  end

  @spec drawable_names() :: [atom()]
  def drawable_names do
    names() -- @non_drawable
  end

  @spec fetch!(atom()) :: keyword()
  def fetch!(name) do
    Keyword.fetch!(@commands, name)
  end

  @spec doc(atom(), keyword()) :: String.t()
  def doc(_name, spec) do
    Keyword.fetch!(spec, :doc)
  end
end
