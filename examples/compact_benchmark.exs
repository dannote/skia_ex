System.put_env("SKIA_EX_BUILD", "1")
Mix.install([
  {:rustler, "~> 0.38.0", runtime: false},
  {:rustq, "~> 0.5", runtime: false},
  {:skia, path: Path.expand("..", __DIR__)}
])

doc =
  Enum.reduce(0..400, Skia.canvas(320, 200) |> Skia.clear("#111827"), fn index, doc ->
    x = rem(index * 17, 320)
    y = rem(index * 31, 200)

    Skia.circle(doc,
      x: x,
      y: y,
      radius: 3 + rem(index, 9),
      fill: if(rem(index, 2) == 0, do: "#38bdf8", else: "#f472b6")
    )
  end)

IO.inspect(Skia.Benchmark.compare(doc), label: "benchmark")

{:ok, png} = Skia.Compact.to_png(doc)
File.write!("compact_benchmark.png", png)
