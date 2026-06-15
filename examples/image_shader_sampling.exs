Mix.install([{:skia, path: Path.expand("..", __DIR__)}])

source =
  Skia.canvas(2, 2)
  |> Skia.rect(x: 0, y: 0, width: 1, height: 1, fill: :red)
  |> Skia.rect(x: 1, y: 0, width: 1, height: 1, fill: :blue)
  |> Skia.rect(x: 0, y: 1, width: 1, height: 1, fill: :green)
  |> Skia.rect(x: 1, y: 1, width: 1, height: 1, fill: :white)

{:ok, source_png} = Skia.to_png(source)
{:ok, image} = Skia.Image.decode(source_png)

doc =
  Skia.canvas(160, 100)
  |> Skia.rect(
    x: 0,
    y: 0,
    width: 160,
    height: 100,
    fill: Skia.Shader.image(image, tile: :repeat, sampling: Skia.SamplingOptions.nearest())
  )

{:ok, png} = Skia.to_png(doc)
File.write!("image_shader_sampling.png", png)
