System.put_env("SKIA_EX_BUILD", "1")
Mix.install([
  {:rustler, "~> 0.38.0", runtime: false},
  {:rustq, "~> 0.5", runtime: false},
  {:skia, path: Path.expand("..", __DIR__)}
])

shader =
  Skia.Shader.sksl!(
    """
    uniform shader child;
    uniform float time;
    uniform vec2 resolution;
    uniform int enabled;

    half4 main(vec2 p) {
      vec2 uv = p / resolution;
      half4 base = child.eval(p);
      float wave = 0.5 + 0.5 * sin(time + uv.x * 24.0);
      return enabled == 1 ? half4(base.r * wave, base.g, uv.y, base.a) : base;
    }
    """,
    uniforms: %{
      time: 1.4,
      resolution: {240, 140},
      enabled: Skia.RuntimeEffect.int(1)
    },
    children: %{
      child: Skia.Shader.linear_gradient({0, 0}, {240, 0}, [:red, :blue])
    }
  )

doc =
  Skia.canvas(240, 140)
  |> Skia.clear("#111827")
  |> Skia.rect(x: 0, y: 0, width: 240, height: 140, fill: shader)

{:ok, png} = Skia.to_png(doc)
File.write!("runtime_effects.png", png)
