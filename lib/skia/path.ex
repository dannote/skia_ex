defmodule Skia.Path do
  import Inspect.Algebra

  @moduledoc """
  Immutable path command list for batched path rendering.
  """

  @type segment ::
          {:move_to, number(), number()}
          | {:line_to, number(), number()}
          | {:quad_to, number(), number(), number(), number()}
          | {:conic_to, number(), number(), number(), number(), number()}
          | {:cubic_to, number(), number(), number(), number(), number(), number()}
          | {:r_move_to, number(), number()}
          | {:r_line_to, number(), number()}
          | {:r_quad_to, number(), number(), number(), number()}
          | {:r_conic_to, number(), number(), number(), number(), number()}
          | {:r_cubic_to, number(), number(), number(), number(), number(), number()}
          | :close

  @type t :: %__MODULE__{segments: [segment()], svg: String.t() | nil}

  defstruct segments: [], svg: nil

  @spec new() :: t()
  def new, do: %__MODULE__{}

  @spec from_svg(String.t()) :: t()
  def from_svg(svg) when is_binary(svg), do: %__MODULE__{svg: svg}

  @spec to_svg(t()) :: {:ok, String.t()} | {:error, atom()}
  def to_svg(%__MODULE__{} = path), do: Skia.Native.path_to_svg(path)

  @spec move_to(t(), number(), number()) :: t()
  def move_to(%__MODULE__{} = path, x, y), do: append(path, {:move_to, f(x), f(y)})

  @spec line_to(t(), number(), number()) :: t()
  def line_to(%__MODULE__{} = path, x, y), do: append(path, {:line_to, f(x), f(y)})

  @spec quad_to(t(), number(), number(), number(), number()) :: t()
  def quad_to(%__MODULE__{} = path, cx, cy, x, y),
    do: append(path, {:quad_to, f(cx), f(cy), f(x), f(y)})

  @spec conic_to(t(), number(), number(), number(), number(), number()) :: t()
  def conic_to(%__MODULE__{} = path, cx, cy, x, y, weight),
    do: append(path, {:conic_to, f(cx), f(cy), f(x), f(y), f(weight)})

  @spec cubic_to(t(), number(), number(), number(), number(), number(), number()) :: t()
  def cubic_to(%__MODULE__{} = path, c1x, c1y, c2x, c2y, x, y) do
    append(path, {:cubic_to, f(c1x), f(c1y), f(c2x), f(c2y), f(x), f(y)})
  end

  @spec r_move_to(t(), number(), number()) :: t()
  def r_move_to(%__MODULE__{} = path, dx, dy), do: append(path, {:r_move_to, f(dx), f(dy)})

  @spec r_line_to(t(), number(), number()) :: t()
  def r_line_to(%__MODULE__{} = path, dx, dy), do: append(path, {:r_line_to, f(dx), f(dy)})

  @spec r_quad_to(t(), number(), number(), number(), number()) :: t()
  def r_quad_to(%__MODULE__{} = path, dcx, dcy, dx, dy),
    do: append(path, {:r_quad_to, f(dcx), f(dcy), f(dx), f(dy)})

  @spec r_conic_to(t(), number(), number(), number(), number(), number()) :: t()
  def r_conic_to(%__MODULE__{} = path, dcx, dcy, dx, dy, weight),
    do: append(path, {:r_conic_to, f(dcx), f(dcy), f(dx), f(dy), f(weight)})

  @spec r_cubic_to(t(), number(), number(), number(), number(), number(), number()) :: t()
  def r_cubic_to(%__MODULE__{} = path, dc1x, dc1y, dc2x, dc2y, dx, dy) do
    append(path, {:r_cubic_to, f(dc1x), f(dc1y), f(dc2x), f(dc2y), f(dx), f(dy)})
  end

  @spec close(t()) :: t()
  def close(%__MODULE__{} = path), do: append(path, :close)

  @spec segments(t()) :: [segment()]
  def segments(%__MODULE__{} = path), do: Enum.reverse(path.segments)

  defp append(%__MODULE__{svg: nil} = path, segment),
    do: %{path | segments: [segment | path.segments]}

  defp append(%__MODULE__{} = path, segment), do: %{path | svg: nil, segments: [segment]}

  defp f(value), do: :erlang.float(value)

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(%{svg: nil} = path, opts) do
      concat([
        "#Skia.Path<segments=",
        to_doc(length(path.segments), opts),
        " closed=",
        to_doc(closed?(path), opts),
        ">"
      ])
    end

    def inspect(%{svg: svg} = path, opts) do
      concat([
        "#Skia.Path<segments=",
        to_doc(length(path.segments), opts),
        " svg=",
        to_doc(is_binary(svg), opts),
        " closed=",
        to_doc(closed?(path), opts),
        ">"
      ])
    end

    defp closed?(path), do: List.first(path.segments) == :close
  end
end
