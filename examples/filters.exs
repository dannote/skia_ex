Mix.install([{:skia, path: Path.expand("..", __DIR__)}])

filter =
  Skia.ImageFilter.blur(2)
  |> Skia.ImageFilter.compose(Skia.ImageFilter.offset(6, 4))

doc =
  Skia.canvas(160, 100)
  |> Skia.clear("#111827")
  |> Skia.layer([image_filter: filter], fn layer ->
    Skia.rect(layer, x: 30, y: 20, width: 80, height: 48, radius: 12, fill: :red)
  end)

{:ok, png} = Skia.to_png(doc)
File.write!("filters.png", png)
