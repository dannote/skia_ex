Mix.install([{:skia, path: Path.expand("..", __DIR__)}])

spans = [
  Skia.TextSpan.new("Hello ", fill: :red, size: 28),
  Skia.TextSpan.new("Skia", fill: :blue, size: 34)
]

doc =
  Skia.canvas(240, 80)
  |> Skia.background(:white)
  |> Skia.text("", x: 12, y: 12, paragraph_style: Skia.ParagraphStyle.new(width: 220), spans: spans)

{:ok, png} = Skia.to_png(doc)
File.write!("text_spans.png", png)
