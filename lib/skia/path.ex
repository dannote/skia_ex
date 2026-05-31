defmodule Skia.Path do
  import Inspect.Algebra

  @moduledoc """
  Immutable path command list for batched path rendering.
  """

  @type segment ::
          {:move_to, number(), number()}
          | {:line_to, number(), number()}
          | {:quad_to, number(), number(), number(), number()}
          | {:cubic_to, number(), number(), number(), number(), number(), number()}
          | :close

  @type t :: %__MODULE__{segments: [segment()]}

  defstruct segments: []

  @spec new() :: t()
  def new, do: %__MODULE__{}

  @spec move_to(t(), number(), number()) :: t()
  def move_to(%__MODULE__{} = path, x, y), do: append(path, {:move_to, x * 1.0, y * 1.0})

  @spec line_to(t(), number(), number()) :: t()
  def line_to(%__MODULE__{} = path, x, y), do: append(path, {:line_to, x * 1.0, y * 1.0})

  @spec quad_to(t(), number(), number(), number(), number()) :: t()
  def quad_to(%__MODULE__{} = path, cx, cy, x, y),
    do: append(path, {:quad_to, cx * 1.0, cy * 1.0, x * 1.0, y * 1.0})

  @spec cubic_to(t(), number(), number(), number(), number(), number(), number()) :: t()
  def cubic_to(%__MODULE__{} = path, c1x, c1y, c2x, c2y, x, y) do
    append(path, {:cubic_to, c1x * 1.0, c1y * 1.0, c2x * 1.0, c2y * 1.0, x * 1.0, y * 1.0})
  end

  @spec close(t()) :: t()
  def close(%__MODULE__{} = path), do: append(path, :close)

  @spec segments(t()) :: [segment()]
  def segments(%__MODULE__{} = path), do: Enum.reverse(path.segments)

  defp append(%__MODULE__{} = path, segment), do: %{path | segments: [segment | path.segments]}

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(path, opts) do
      concat([
        "#Skia.Path<segments=",
        to_doc(length(path.segments), opts),
        " closed=",
        to_doc(closed?(path), opts),
        ">"
      ])
    end

    defp closed?(path), do: List.first(path.segments) == :close
  end
end
