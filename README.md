# Skia

Batched, Elixir-native drawing API backed by Rustler + `skia-safe`.

The public API builds immutable Elixir documents. Rendering crosses the native
boundary once with a normalized command batch instead of calling a NIF for every
canvas operation.

## Example

```elixir
document =
  Skia.canvas(1200, 630)
  |> Skia.clear("#020617")
  |> Skia.group([translate: {80, 80}], fn doc ->
    doc
    |> Skia.text("Launch Week", x: 48, y: 90, size: 56, weight: 700, fill: :white)
    |> Skia.rect(x: 48, y: 140, width: 320, height: 96, radius: 24, fill: "#3b82f6")
  end)

{:ok, png} = Skia.to_png(document)
{:ok, png} = Skia.render(document, format: :png)
{:ok, %{width: width, height: height, stride: stride, data: rgba}} = Skia.render(document, Skia.RenderOptions.new(format: :raw))
```

## Paint sources and shaders

```elixir
fill =
  Skia.Shader.two_point_conical_gradient({16, 16}, 0, {48, 48}, 32, [
    Skia.Shader.stop(:red, 0),
    Skia.Shader.stop(:blue, 1)
  ], tile: :clamp, matrix: Skia.Matrix.rotate(0.2))

solid_shader = Skia.Shader.color(:green)
```

Image shaders support tile modes and rich sampling:

```elixir
Skia.Shader.image(image,
  tile: {:repeat, :mirror},
  sampling: Skia.SamplingOptions.cubic(:catmull_rom),
  matrix: Skia.Matrix.scale(2, 2)
)
```

## Filters and effects

Paints can carry image filters, color filters, mask filters, blend modes, and path effects. You can pass options directly or build a reusable `%Skia.Paint{}`:

```elixir
paint = Skia.Paint.new(fill: :red, image_filter: Skia.ImageFilter.blur(2), blend_mode: :src_over)
Skia.rect(doc, x: 0, y: 0, width: 100, height: 100, paint: paint)

color_filter =
  Skia.ColorFilter.blend(:blue, :src_in)
  |> Skia.ColorFilter.compose(Skia.ColorFilter.matrix([
    1, 0, 0, 0, 0,
    0, 1, 0, 0, 0,
    0, 0, 1, 0, 0,
    0, 0, 0, 1, 0
  ]))

path_effect =
  Skia.PathEffect.trim(0.05, 0.95)
  |> Skia.PathEffect.compose(Skia.PathEffect.dash([8, 4]))
  |> Skia.PathEffect.sum(Skia.PathEffect.discrete(6, 1.5, seed: 42))

stamp = Skia.Path.new() |> Skia.Path.move_to(0, 0) |> Skia.Path.line_to(1, 1)
advanced_effect = Skia.PathEffect.path_1d(stamp, 8, style: :rotate)

Skia.path(doc, path,
  stroke: :red,
  stroke_width: 2,
  blend_mode: :src_over,
  color_filter: color_filter,
  image_filter: Skia.ImageFilter.blur(2),
  mask_filter: Skia.MaskFilter.blur(1.5, style: :normal),
  path_effect: path_effect
)
```

Layer and image-filter graphs are composable:

```elixir
filter =
  Skia.ImageFilter.blur(2)
  |> Skia.ImageFilter.compose(Skia.ImageFilter.offset(4, 2))
  |> Skia.ImageFilter.compose(Skia.ImageFilter.matrix_transform(Skia.Matrix.scale(1.2, 1.2)))

advanced = Skia.ImageFilter.merge([
  Skia.ImageFilter.magnifier({0, 0, 100, 100}, 1.5, 4),
  Skia.ImageFilter.tile({0, 0, 20, 20}, {0, 0, 100, 100}),
  Skia.ImageFilter.matrix_convolution({1, 1}, [1.0])
])

Skia.layer(doc, [image_filter: filter], fn layer ->
  Skia.rect(layer, x: 0, y: 0, width: 80, height: 80, fill: :red)
end)
```

## Paths

Paths are immutable Elixir structs and support absolute, relative, conic, cubic,
SVG import, and SVG export:

```elixir
path =
  Skia.Path.new()
  |> Skia.Path.move_to(0, 0)
  |> Skia.Path.r_line_to(40, 0)
  |> Skia.Path.conic_to(60, 20, 40, 40, 0.5)
  |> Skia.Path.arc_to({0, 0, 80, 80}, 0, 180, force_move_to: false)
  |> Skia.Path.rrect({10, 10, 40, 24}, 6)
  |> Skia.Path.close()

svg_path = Skia.Path.from_svg("M0 0L100 0L100 100Z")
{:ok, svg} = Skia.Path.to_svg(svg_path)
```

## Pictures

Record reusable drawing subtrees as Skia pictures and replay them later:

```elixir
{:ok, picture} =
  Skia.canvas(64, 64)
  |> Skia.rect(x: 0, y: 0, width: 64, height: 64, fill: :red)
  |> Skia.Picture.record()

{:ok, info} = Skia.Picture.info(picture)
{:ok, bytes} = Skia.Picture.encode(picture)
{:ok, picture} = Skia.Picture.decode(bytes, width: 64, height: 64)
{:ok, image} = Skia.Image.from_picture(picture)

Skia.canvas(256, 64)
|> Skia.picture(picture, x: 96, y: 0, opacity: 0.75)

Skia.rect(doc, x: 0, y: 0, width: 128, height: 128, fill: Skia.Shader.picture(picture))
```

## Fonts and typefaces

`Skia.Typeface` represents the reusable font face; `Skia.Font` adds size for drawing and measurement.

```elixir
{:ok, families} = Skia.Typeface.families()
{:ok, typeface} = Skia.Typeface.match_family("Inter", weight: 700, slant: :upright)
font = Skia.Font.new(typeface, size: 24)
{:ok, info} = Skia.Typeface.info(typeface)
{:ok, metrics} = Skia.Font.metrics(font)
{:ok, glyphs} = Skia.Font.glyph_ids(font, "Hello")
{:ok, measurement} = Skia.measure_text("Hello", font: font)
```

Loaded images, fonts, and pictures keep decoded Skia handles in their native
resources for repeated drawing, while pictures still retain serialized bytes for
`Skia.Picture.encode/1`.

## Text

Use direct options for convenience or reusable style structs for paragraph text:

```elixir
style = Skia.TextStyle.new(size: 16, fill: :black, font_family: "Arial", line_height: 20)
paragraph = Skia.ParagraphStyle.new(width: 320, align: :center, direction: :ltr)

spans = [
  Skia.TextSpan.new("Hello ", fill: :red, size: 18),
  Skia.TextSpan.new("Skia", fill: :blue, size: 24)
]

Skia.text(doc, "Hello", x: 0, y: 0, style: style, paragraph_style: paragraph)
Skia.text(doc, "", x: 0, y: 32, paragraph_style: paragraph, spans: spans)

{:ok, blob} = Skia.TextBlob.new("Cached", font: font)
{:ok, bounds} = Skia.TextBlob.bounds(blob)
Skia.text_blob(doc, blob, x: 0, y: 64, fill: :black)
```

## Vertices

Draw triangle meshes with per-vertex colors:

```elixir
vertices = Skia.Vertices.new([{0, 0}, {100, 0}, {50, 100}], colors: [:red, :green, :blue])
Skia.vertices(doc, vertices)
```

## Compact batches and benchmarking

`Skia.to_batch/1` returns the normal map/struct batch consumed by the native renderer.
Encode normal batches directly with `:erlang.term_to_binary(Skia.to_batch(document))`.
`Skia.Compact.encode/1` uses stable operation ids and compact color/path values, and
`Skia.Compact.encode_binary/1` writes compressed ETF. Compact batches can also render
through native compact decode:

```elixir
{:ok, raw} = Skia.Compact.to_raw(document)
{:ok, png} = Skia.Compact.render(document, format: :png)

{:ok, stats} = Skia.Benchmark.compare(document, iterations: 20)
stats.normal_batch_bytes
stats.compact_batch_bytes
stats.compact_render_us
stats.picture_replay_us
```

Native operations return tagged errors such as `:invalid_image`, `:invalid_picture`,
`:invalid_path`, and `:invalid_command` instead of leaking raw NIF badarg failures
through public helpers.

## Development

```sh
mix deps.get
mix ci

# Force local Rustler build instead of downloading a precompiled NIF.
SKIA_EX_BUILD=1 mix compile
```

See `docs/commands.md` for the generated command reference.
