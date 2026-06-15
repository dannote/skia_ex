System.put_env("SKIA_EX_BUILD", "1")
Mix.install([
  {:rustler, "~> 0.38.0", runtime: false},
  {:rustq, "~> 0.5", runtime: false},
  {:skia, path: Path.expand("..", __DIR__)}
])

mesh =
  Skia.Vertices.new(
    [{20, 20}, {220, 30}, {120, 130}, {40, 120}, {210, 120}],
    mode: :triangle_fan,
    colors: [:red, :green, :blue, "#f59e0b", "#8b5cf6"]
  )

doc =
  Skia.canvas(240, 150)
  |> Skia.clear("#0f172a")
  |> Skia.vertices(mesh)

{:ok, png} = Skia.to_png(doc)
File.write!("vertices.png", png)
