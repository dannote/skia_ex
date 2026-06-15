Mix.install([{:skia, path: Path.expand("..", __DIR__)}])

path = Skia.Path.from_svg("M20 10L140 10L80 90Z")

doc =
  Skia.canvas(160, 100)
  |> Skia.clear(:white)
  |> Skia.path(path, fill: Skia.Shader.two_point_conical_gradient({40, 20}, 0, {120, 80}, 60, [:red, :blue]))

{:ok, png} = Skia.render(doc, Skia.RenderOptions.new(format: :png))
File.write!("svg_paths_render_options.png", png)

IO.inspect(Skia.Compact.encode(doc), label: "compact batch")
