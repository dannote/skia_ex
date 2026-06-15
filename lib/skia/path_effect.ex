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

  @type t :: Dash.t() | Corner.t() | Compose.t() | Sum.t()

  @spec dash([number()], keyword()) :: Dash.t()
  def dash(intervals, opts \\ []) when is_list(intervals) do
    %Dash{
      intervals: Enum.map(intervals, &:erlang.float/1),
      phase: :erlang.float(Keyword.get(opts, :phase, 0))
    }
  end

  @spec corner(number()) :: Corner.t()
  def corner(radius), do: %Corner{radius: :erlang.float(radius)}

  @spec compose(t(), t()) :: Compose.t()
  def compose(outer, inner), do: %Compose{outer: outer, inner: inner}

  @spec sum(t(), t()) :: Sum.t()
  def sum(first, second), do: %Sum{first: first, second: second}
end
