defmodule Skia.TextStyle do
  @moduledoc "Reusable text style options for `Skia.text/3`."

  @type t :: %__MODULE__{
          size: number() | nil,
          fill: term() | nil,
          font: Skia.Font.t() | nil,
          weight: integer() | nil,
          font_family: String.t() | nil,
          line_height: number() | nil
        }
  defstruct [:size, :fill, :font, :weight, :font_family, :line_height]

  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    struct(
      __MODULE__,
      Keyword.take(opts, [:size, :fill, :font, :weight, :font_family, :line_height])
    )
  end

  @spec to_opts(t()) :: keyword()
  def to_opts(%__MODULE__{} = style) do
    style
    |> Map.from_struct()
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end
end
