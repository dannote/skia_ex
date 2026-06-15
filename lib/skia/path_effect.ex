defmodule Skia.PathEffect do
  @moduledoc "Path effect values for stroke paints."

  defmodule Dash do
    @moduledoc "Dash path effect."
    @type t :: %__MODULE__{intervals: [float()], phase: float()}
    defstruct [:intervals, phase: 0.0]
  end

  defmodule Corner do
    @moduledoc "Corner rounding path effect."
    @type t :: %__MODULE__{radius: float()}
    defstruct [:radius]
  end

  defmodule Trim do
    @moduledoc "Trim path effect."
    @type t :: %__MODULE__{start: float(), stop: float(), mode: :normal | :inverted}
    defstruct [:start, :stop, mode: :normal]
  end

  defmodule Discrete do
    @moduledoc "Discrete/jitter path effect."
    @type t :: %__MODULE__{
            segment_length: float(),
            deviation: float(),
            seed: non_neg_integer() | nil
          }
    defstruct [:segment_length, :deviation, :seed]
  end

  defmodule Path1D do
    @moduledoc "Stamp a path along stroked contours."
    @type t :: %__MODULE__{path: Skia.Path.t(), advance: float(), phase: float(), style: atom()}
    defstruct [:path, :advance, phase: 0.0, style: :translate]
  end

  defmodule Line2D do
    @moduledoc "2D line path effect."
    @type t :: %__MODULE__{width: float(), matrix: Skia.Matrix.t()}
    defstruct [:width, :matrix]
  end

  defmodule Path2D do
    @moduledoc "2D path stamp effect."
    @type t :: %__MODULE__{matrix: Skia.Matrix.t(), path: Skia.Path.t()}
    defstruct [:matrix, :path]
  end

  defmodule Compose do
    @moduledoc "Path effect composition."
    @type t :: %__MODULE__{outer: Skia.PathEffect.t(), inner: Skia.PathEffect.t()}
    defstruct [:outer, :inner]
  end

  defmodule Sum do
    @moduledoc "Path effect sum."
    @type t :: %__MODULE__{first: Skia.PathEffect.t(), second: Skia.PathEffect.t()}
    defstruct [:first, :second]
  end

  @type t ::
          Dash.t()
          | Corner.t()
          | Trim.t()
          | Discrete.t()
          | Path1D.t()
          | Line2D.t()
          | Path2D.t()
          | Compose.t()
          | Sum.t()

  @spec dash([number()], keyword()) :: Dash.t()
  def dash(intervals, opts \\ []) when is_list(intervals) do
    %Dash{
      intervals: Enum.map(intervals, &:erlang.float/1),
      phase: :erlang.float(Keyword.get(opts, :phase, 0))
    }
  end

  @spec corner(number()) :: Corner.t()
  def corner(radius), do: %Corner{radius: :erlang.float(radius)}

  @spec trim(number(), number(), keyword()) :: Trim.t()
  def trim(start, stop, opts \\ []) do
    %Trim{
      start: :erlang.float(start),
      stop: :erlang.float(stop),
      mode: Keyword.get(opts, :mode, :normal)
    }
  end

  @spec discrete(number(), number(), keyword()) :: Discrete.t()
  def discrete(segment_length, deviation, opts \\ []) do
    %Discrete{
      segment_length: :erlang.float(segment_length),
      deviation: :erlang.float(deviation),
      seed: Keyword.get(opts, :seed)
    }
  end

  @spec path_1d(Skia.Path.t(), number(), keyword()) :: Path1D.t()
  def path_1d(%Skia.Path{} = path, advance, opts \\ []) do
    %Path1D{
      path: path,
      advance: :erlang.float(advance),
      phase: :erlang.float(Keyword.get(opts, :phase, 0)),
      style: Keyword.get(opts, :style, :translate)
    }
  end

  @spec line_2d(number(), Skia.Matrix.t()) :: Line2D.t()
  def line_2d(width, %Skia.Matrix{} = matrix),
    do: %Line2D{width: :erlang.float(width), matrix: matrix}

  @spec path_2d(Skia.Matrix.t(), Skia.Path.t()) :: Path2D.t()
  def path_2d(%Skia.Matrix{} = matrix, %Skia.Path{} = path),
    do: %Path2D{matrix: matrix, path: path}

  @spec compose(t(), t()) :: Compose.t()
  def compose(outer, inner), do: %Compose{outer: outer, inner: inner}

  @spec sum(t(), t()) :: Sum.t()
  def sum(first, second), do: %Sum{first: first, second: second}
end
