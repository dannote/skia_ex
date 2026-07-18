defmodule Skia.ParagraphStyle do
  @moduledoc "Reusable paragraph layout options for `Skia.text/3`."

  @type t :: %__MODULE__{
          width: number() | nil,
          height: number() | nil,
          align: atom() | nil,
          vertical_align: :top | :center | :bottom | nil,
          direction: atom() | nil,
          max_lines: non_neg_integer() | nil,
          ellipsis: String.t() | nil
        }
  defstruct [:width, :height, :align, :vertical_align, :direction, :max_lines, :ellipsis]

  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    struct(
      __MODULE__,
      Keyword.take(opts, [
        :width,
        :height,
        :align,
        :vertical_align,
        :direction,
        :max_lines,
        :ellipsis
      ])
    )
  end

  @spec to_opts(t()) :: keyword()
  def to_opts(%__MODULE__{} = style) do
    style
    |> Map.from_struct()
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end
end
