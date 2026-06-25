defmodule Skia.MixProject do
  use Mix.Project

  @version "0.2.0"
  @source_url "https://github.com/dannote/skia_ex"

  def project do
    [
      app: :skia,
      version: @version,
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      dialyzer: [plt_add_apps: [:mix, :rustq], ignore_warnings: ".dialyzer_ignore.exs"],
      name: "Skia",
      description: "Elixir drawing API backed by a batched Rustler Skia renderer",
      source_url: @source_url,
      homepage_url: @source_url,
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def cli do
    [
      preferred_envs: [ci: :test]
    ]
  end

  defp deps do
    [
      {:ex_slop, "~> 0.4", only: [:dev, :test], runtime: false},
      {:reach, "~> 2.0", only: [:dev, :test], runtime: false},
      {:ex_dna, "~> 1.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:ex_doc, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:rustler_precompiled, "~> 0.8"},
      {:rustler, "~> 0.38.0", optional: true, runtime: false},
      {:rustq, "~> 0.7", only: [:dev, :test], runtime: false},
      {:vibe_kit, "~> 0.1"},
      {:igniter, "~> 0.6", only: [:dev, :test]}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files:
        [
          "lib",
          "native/skia_native/src",
          "native/skia_native/Cargo.toml",
          "native/skia_native/Cargo.lock",
          "examples",
          "mix.exs",
          "README.md",
          "LICENSE"
        ] ++ Path.wildcard("checksum-*.exs")
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_ref: "v#{@version}",
      source_url: @source_url,
      filter_modules: &public_doc_module?/2
    ]
  end

  defp public_doc_module?(module, _metadata) do
    module
    |> inspect()
    |> then(fn name ->
      String.starts_with?(name, "Skia") and not String.starts_with?(name, "Skia.Codegen")
    end)
  end

  defp aliases() do
    [
      ci: [
        "compile --warnings-as-errors",
        "rustq.gen --check",
        "format --check-formatted",
        "test",
        "docs --warnings-as-errors",
        "credo --strict",
        "dialyzer",
        "ex_dna --max-clones 0",
        "reach.check --arch --smells"
      ]
    ]
  end
end
