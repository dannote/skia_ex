defmodule Skia.SamplingOptions do
  @moduledoc "Image sampling options for image drawing and image shaders."

  @type cubic :: :mitchell | :catmull_rom | {number(), number()}
  @type t :: %__MODULE__{
          filter: atom(),
          mipmap: atom(),
          cubic: cubic() | nil,
          max_aniso: pos_integer() | nil
        }
  defstruct filter: :nearest, mipmap: :none, cubic: nil, max_aniso: nil

  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      filter: Keyword.get(opts, :filter, :nearest),
      mipmap: Keyword.get(opts, :mipmap, :none),
      cubic: Keyword.get(opts, :cubic),
      max_aniso: Keyword.get(opts, :max_aniso)
    }
  end

  @spec nearest() :: t()
  def nearest, do: new(filter: :nearest)

  @spec linear() :: t()
  def linear, do: new(filter: :linear)

  @spec mipmap(atom(), atom()) :: t()
  def mipmap(filter \\ :linear, mipmap \\ :linear), do: new(filter: filter, mipmap: mipmap)

  @spec cubic(cubic()) :: t()
  def cubic(cubic), do: new(cubic: cubic)

  @spec aniso(pos_integer()) :: t()
  def aniso(max_aniso), do: new(max_aniso: max_aniso)
end
