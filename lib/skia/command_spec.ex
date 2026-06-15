defmodule Skia.CommandSpec do
  @moduledoc """
  Source of truth for the curated Elixir drawing API.

  Domain modules define small command groups. Skia enum variants and Rust
  doc/native-reference checks are inferred from local `skia-safe`/
  `skia-bindings` sources by `Skia.Codegen.SkiaSafe`.
  """

  @domains [
    Skia.CommandSpec.Shapes,
    Skia.CommandSpec.Text,
    Skia.CommandSpec.Images,
    Skia.CommandSpec.Layers,
    Skia.CommandSpec.Transforms,
    Skia.CommandSpec.Paths,
    Skia.CommandSpec.Clips
  ]

  @spec all() :: keyword()
  def all do
    Enum.flat_map(@domains, & &1.commands())
  end

  @spec names() :: [atom()]
  def names, do: Keyword.keys(all())

  @spec drawable_names() :: [atom()]
  def drawable_names do
    names() --
      [
        :save,
        :save_layer,
        :restore,
        :translate,
        :scale,
        :rotate,
        :rotate_at,
        :concat,
        :push_style,
        :pop_style
      ]
  end

  @spec fetch!(atom()) :: keyword()
  def fetch!(name), do: Keyword.fetch!(all(), name)
end
