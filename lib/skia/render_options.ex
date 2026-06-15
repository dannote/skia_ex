defmodule Skia.RenderOptions do
  @moduledoc "Rendering options for `Skia.render/2`."

  @type format :: :png | :jpeg | :webp | :raw
  @type t :: %__MODULE__{format: format(), quality: 1..100 | nil}
  defstruct format: :png, quality: nil

  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{format: Keyword.get(opts, :format, :png), quality: Keyword.get(opts, :quality)}
  end
end
