defmodule Skia.Vertices do
  @moduledoc "Triangle mesh vertices."

  @type point :: {number(), number()}
  @type t :: %__MODULE__{
          mode: atom(),
          positions: [point()],
          colors: [term()],
          indices: [non_neg_integer()] | nil
        }
  defstruct mode: :triangles, positions: [], colors: [], indices: nil

  @spec new([point()], keyword()) :: t()
  def new(positions, opts \\ []) when is_list(positions) do
    %__MODULE__{
      mode: Keyword.get(opts, :mode, :triangles),
      positions: positions,
      colors: Keyword.get(opts, :colors, List.duplicate(:white, length(positions))),
      indices: Keyword.get(opts, :indices)
    }
  end
end
