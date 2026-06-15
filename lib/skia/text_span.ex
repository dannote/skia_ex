defmodule Skia.TextSpan do
  @moduledoc "Styled text run for paragraph rendering."

  @type t :: %__MODULE__{text: String.t(), style: Skia.TextStyle.t() | nil}
  defstruct [:text, :style]

  @spec new(String.t(), keyword()) :: t()
  def new(text, opts \\ []) when is_binary(text) do
    %__MODULE__{text: text, style: Keyword.get(opts, :style, Skia.TextStyle.new(opts))}
  end
end
