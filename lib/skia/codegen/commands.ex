defmodule Skia.Codegen.Commands do
  @moduledoc false

  @domains [
    Skia.Codegen.Commands.Shapes,
    Skia.Codegen.Commands.Text,
    Skia.Codegen.Commands.Images,
    Skia.Codegen.Commands.Layers,
    Skia.Codegen.Commands.Transforms,
    Skia.Codegen.Commands.Paths,
    Skia.Codegen.Commands.Clips
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
