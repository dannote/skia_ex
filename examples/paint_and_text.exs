{:ok, measurement} = Skia.measure_text("Skia", size: 48)
IO.inspect(measurement, label: "measurement")

document =
  Skia.canvas(320, 180)
  |> Skia.background("#111827")
  |> Skia.rect(
    x: 24,
    y: 24,
    width: 272,
    height: 96,
    radius: 24,
    fill: Skia.linear_gradient({24, 24}, {296, 120}, [:red, :blue])
  )
  |> Skia.line(
    from: {32, 144},
    to: {288, 144},
    stroke: :white,
    stroke_width: 12,
    stroke_cap: :round
  )
  |> Skia.text("Skia", x: 96, y: 88, size: 48, fill: :white)

{:ok, png} = Skia.to_png(document)
File.write!("paint_and_text.png", png)
