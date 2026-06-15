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

  @type t :: Dash.t() | Corner.t() | Trim.t() | Discrete.t() | Compose.t() | Sum.t()

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

  @spec compose(t(), t()) :: Compose.t()
  def compose(outer, inner), do: %Compose{outer: outer, inner: inner}

  @spec sum(t(), t()) :: Sum.t()
  def sum(first, second), do: %Sum{first: first, second: second}
end
