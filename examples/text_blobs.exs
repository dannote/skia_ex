System.put_env("SKIA_EX_BUILD", "1")
Mix.install([
  {:rustler, "~> 0.38.0", runtime: false},
  {:rustq, "~> 0.5", runtime: false},
  {:skia, path: Path.expand("..", __DIR__)}
])

{:ok, blob} = Skia.TextBlob.new("TextBlob", size: 40)
{:ok, bounds} = Skia.TextBlob.bounds(blob)
IO.inspect(bounds, label: "bounds")

doc =
  Skia.canvas(260, 100)
  |> Skia.clear("#111827")
  |> Skia.text_blob(blob, x: 24, y: 62, fill: "#f8fafc")

{:ok, png} = Skia.to_png(doc)
File.write!("text_blobs.png", png)
