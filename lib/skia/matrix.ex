defmodule Skia.Matrix do
  @moduledoc "2D affine transform matrix used by shaders and canvas transforms."

  @type t :: %__MODULE__{values: {float(), float(), float(), float(), float(), float()}}
  defstruct [:values]

  @doc "Creates a matrix from Skia's 2D affine tuple `{sx, kx, tx, ky, sy, ty}`."
  @spec new({number(), number(), number(), number(), number(), number()}) :: t()
  def new({sx, kx, tx, ky, sy, ty}) do
    %__MODULE__{values: {sx * 1.0, kx * 1.0, tx * 1.0, ky * 1.0, sy * 1.0, ty * 1.0}}
  end

  @doc "Identity matrix."
  @spec identity() :: t()
  def identity, do: new({1, 0, 0, 0, 1, 0})

  @doc "Translation matrix."
  @spec translate(number(), number()) :: t()
  def translate(x, y), do: new({1, 0, x, 0, 1, y})

  @doc "Scale matrix."
  @spec scale(number(), number()) :: t()
  def scale(x, y), do: new({x, 0, 0, 0, y, 0})

  @doc "Rotation matrix around the origin, in degrees."
  @spec rotate(number()) :: t()
  def rotate(degrees) do
    radians = degrees * :math.pi() / 180.0
    cos = :math.cos(radians)
    sin = :math.sin(radians)
    new({cos, -sin, 0, sin, cos, 0})
  end

  @doc "Skew matrix."
  @spec skew(number(), number()) :: t()
  def skew(x, y), do: new({1, x, 0, y, 1, 0})

  @doc false
  @spec to_tuple(t()) :: {float(), float(), float(), float(), float(), float()}
  def to_tuple(%__MODULE__{values: values}), do: values
end
