defmodule Skia.ParagraphStyle do
  @moduledoc "Reusable paragraph layout options for `Skia.text/3`."

  @type t :: %__MODULE__{
          width: number() | nil,
          align: atom() | nil,
          direction: atom() | nil
        }
  defstruct [:width, :align, :direction]

  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    struct(__MODULE__, Keyword.take(opts, [:width, :align, :direction]))
  end

  @spec to_opts(t()) :: keyword()
  def to_opts(%__MODULE__{} = style) do
    style
    |> Map.from_struct()
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end
end
