System.put_env("SKIA_EX_BUILD", "1")
Mix.install([
  {:rustler, "~> 0.38.0", runtime: false},
  {:rustq, "~> 0.5", runtime: false},
  {:skia, path: Path.expand("..", __DIR__)}
])

{:ok, families} = Skia.Typeface.families()
families = Enum.take(families, 8)
IO.inspect(families, label: "families")

family = Enum.find(families, &String.contains?(&1, "Sans")) || List.first(families) || "DejaVu Sans"
{:ok, typeface} = Skia.Typeface.match_family(family, weight: 700)
{:ok, info} = Skia.Typeface.info(typeface)
font = Skia.Font.new(typeface, size: 28)
{:ok, metrics} = Skia.Font.metrics(font)
{:ok, glyphs} = Skia.Font.glyph_ids(font, "Typeface")

IO.inspect(info, label: "typeface")
IO.inspect(metrics, label: "metrics")
IO.inspect(glyphs, label: "glyph ids")

doc =
  Skia.canvas(280, 100)
  |> Skia.clear("#111827")
  |> Skia.text("Typeface", x: 24, y: 58, font: font, fill: "#f8fafc")

{:ok, png} = Skia.to_png(doc)
File.write!("typefaces.png", png)
