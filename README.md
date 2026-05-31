# Skia

Batched, Elixir-native drawing API for a future Rustler + Skia renderer.

The public API builds immutable Elixir documents. Rendering crosses the native
boundary once with a normalized command batch instead of calling a NIF for every
canvas operation.

## Example

```elixir
use Skia.DSL

document =
  canvas 1200, 630 do
    background "#020617"

    group translate: {80, 80} do
      style fill: :white, font: "Inter" do
        text "Launch Week", x: 48, y: 90, size: 56, weight: 700
        rect x: 48, y: 140, width: 320, height: 96, radius: 24, fill: "#3b82f6"
      end
    end
  end

{:ok, png} = Skia.to_png(document)
{:ok, %{width: width, height: height, stride: stride, data: rgba}} = Skia.to_raw(document)
```

The Rustler native boundary is already present. The current NIF uses
`skia-safe` for CPU raster rendering and supports the first batch commands:
background clears, rectangles, circles, lines, paths, text, decoded images,
image source rectangles, clip rectangles/circles/paths, save/restore, layers,
translate, and rotate. PNG, JPEG, raw RGBA, and WEBP encoding entry points are
available; WEBP depends on the native Skia build supporting WEBP encoding.

See `examples/` for runnable snippets covering images, clipping, gradients,
stroke options, and text measurement.

## Installation

After publication, add `skia` to your dependencies:

```elixir
def deps do
  [
    {:skia, "~> 0.1.0"}
  ]
end
```

## Development

```sh
mix deps.get
mix ci
```
