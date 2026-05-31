defmodule Skia.CommandSpec do
  @moduledoc """
  Source of truth for generated fluent functions and DSL commands.
  """

  @commands [
    background: [
      op: :clear,
      args: [color: :color],
      opts: []
    ],
    rect: [
      args: [],
      defaults: [radius: 0],
      opts: [
        [name: :x, type: :number, required: true],
        [name: :y, type: :number, required: true],
        [name: :width, type: :number, required: true],
        [name: :height, type: :number, required: true],
        [name: :radius, type: :number],
        [name: :fill, type: :color],
        [name: :stroke, type: :color],
        [name: :stroke_width, type: :number],
        [name: :stroke_cap, type: :atom],
        [name: :stroke_join, type: :atom],
        [name: :stroke_miter, type: :number],
        [name: :blend_mode, type: :atom]
      ]
    ],
    circle: [
      args: [],
      opts: [
        [name: :x, type: :number, required: true],
        [name: :y, type: :number, required: true],
        [name: :radius, type: :number, required: true],
        [name: :fill, type: :color],
        [name: :stroke, type: :color],
        [name: :stroke_width, type: :number],
        [name: :stroke_cap, type: :atom],
        [name: :stroke_join, type: :atom],
        [name: :stroke_miter, type: :number],
        [name: :blend_mode, type: :atom]
      ]
    ],
    line: [
      args: [],
      opts: [
        [name: :from, type: {:tuple, [:number, :number]}, required: true],
        [name: :to, type: {:tuple, [:number, :number]}, required: true],
        [name: :stroke, type: :color, required: true],
        [name: :stroke_width, type: :number],
        [name: :stroke_cap, type: :atom],
        [name: :stroke_join, type: :atom],
        [name: :stroke_miter, type: :number],
        [name: :blend_mode, type: :atom]
      ]
    ],
    text: [
      args: [text: :string],
      defaults: [size: 16, fill: :black],
      opts: [
        [name: :x, type: :number, required: true],
        [name: :y, type: :number, required: true],
        [name: :size, type: :number],
        [name: :fill, type: :color],
        [name: :font, type: :font],
        [name: :weight, type: :integer]
      ]
    ],
    image: [
      args: [image: :image],
      opts: [
        [name: :x, type: :number, required: true],
        [name: :y, type: :number, required: true],
        [name: :width, type: :number],
        [name: :height, type: :number],
        [name: :source, type: {:tuple, [:number, :number, :number, :number]}],
        [name: :opacity, type: :number],
        [name: :sampling, type: :atom],
        [name: :blend_mode, type: :atom]
      ]
    ],
    save: [args: [], opts: []],
    save_layer: [args: [], defaults: [opacity: 1.0], opts: [[name: :opacity, type: :number]]],
    restore: [args: [], opts: []],
    translate: [
      args: [],
      opts: [
        [name: :x, type: :number, required: true],
        [name: :y, type: :number, required: true]
      ]
    ],
    rotate: [
      args: [],
      opts: [[name: :degrees, type: :number, required: true]]
    ],
    push_style: [args: [], opts: [[name: :style, type: :term, required: true]]],
    pop_style: [args: [], opts: []],
    path: [
      args: [path: :path],
      opts: [
        [name: :fill, type: :color],
        [name: :stroke, type: :color],
        [name: :stroke_width, type: :number],
        [name: :stroke_cap, type: :atom],
        [name: :stroke_join, type: :atom],
        [name: :stroke_miter, type: :number],
        [name: :blend_mode, type: :atom],
        [name: :fill_rule, type: :atom]
      ]
    ],
    clip_rect: [
      args: [],
      defaults: [radius: 0, antialias: true],
      opts: [
        [name: :x, type: :number, required: true],
        [name: :y, type: :number, required: true],
        [name: :width, type: :number, required: true],
        [name: :height, type: :number, required: true],
        [name: :radius, type: :number],
        [name: :antialias, type: :boolean]
      ]
    ],
    clip_circle: [
      args: [],
      defaults: [antialias: true],
      opts: [
        [name: :x, type: :number, required: true],
        [name: :y, type: :number, required: true],
        [name: :radius, type: :number, required: true],
        [name: :antialias, type: :boolean]
      ]
    ],
    clip_path: [
      args: [path: :path],
      defaults: [antialias: true, fill_rule: :winding],
      opts: [
        [name: :antialias, type: :boolean],
        [name: :fill_rule, type: :atom]
      ]
    ]
  ]

  @spec all() :: keyword()
  def all, do: @commands

  @spec names() :: [atom()]
  def names, do: Keyword.keys(@commands)

  @spec drawable_names() :: [atom()]
  def drawable_names do
    names() -- [:save, :save_layer, :restore, :translate, :rotate, :push_style, :pop_style]
  end

  @spec fetch!(atom()) :: keyword()
  def fetch!(name), do: Keyword.fetch!(@commands, name)
end
