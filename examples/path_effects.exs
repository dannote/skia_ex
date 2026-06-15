Mix.install([{:skia, path: Path.expand("..", __DIR__)}])

path =
  Skia.Path.new()
  |> Skia.Path.move_to(10, 60)
  |> Skia.Path.cubic_to(50, 0, 110, 120, 150, 60)

effect =
  Skia.PathEffect.dash([10, 5])
  |> Skia.PathEffect.compose(Skia.PathEffect.corner(4))

doc =
  Skia.canvas(160, 100)
  |> Skia.clear(:white)
  |> Skia.path(path, stroke: :blue, stroke_width: 4, path_effect: effect)

{:ok, png} = Skia.to_png(doc)
File.write!("path_effects.png", png)
