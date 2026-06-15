source =
  Skia.canvas(64, 64)
  |> Skia.clear(:transparent)
  |> Skia.rect(x: 0, y: 0, width: 32, height: 64, fill: :red)
  |> Skia.rect(x: 32, y: 0, width: 32, height: 64, fill: :blue)

{:ok, png} = Skia.to_png(source)
{:ok, image} = Skia.Image.decode(png)
{:ok, cropped} = Skia.Image.crop(image, {32, 0, 32, 64})
{:ok, resized} = Skia.Image.resize(cropped, 128, 128)

mask =
  Skia.Path.new()
  |> Skia.Path.move_to(16, 16)
  |> Skia.Path.line_to(144, 16)
  |> Skia.Path.line_to(80, 144)
  |> Skia.Path.close()

document =
  Skia.canvas(160, 160)
  |> Skia.clear(:white)
  |> Skia.clip_path(mask)
  |> Skia.image(resized, x: 16, y: 16, width: 128, height: 128, sampling: :linear)

{:ok, output} = Skia.to_png(document)
File.write!("images_and_clips.png", output)
