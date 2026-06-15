defmodule Skia.Font do
  import Inspect.Algebra

  @moduledoc """
  Sized font value built from a `Skia.Typeface`.

      {:ok, typeface} = Skia.Typeface.match_family("Inter", weight: 700)
      font = Skia.Font.new(typeface, size: 18)
  """

  @type t :: %__MODULE__{typeface: Skia.Typeface.t() | nil, size: float() | nil}
  defstruct [:typeface, :size]

  @spec new(Skia.Typeface.t() | nil, keyword()) :: t()
  def new(typeface \\ nil, opts \\ [])
  def new(nil, opts), do: %__MODULE__{size: normalize_size(Keyword.get(opts, :size))}

  def new(%Skia.Typeface{} = typeface, opts),
    do: %__MODULE__{typeface: typeface, size: normalize_size(Keyword.get(opts, :size))}

  defp normalize_size(nil), do: nil
  defp normalize_size(size) when is_number(size), do: :erlang.float(size)

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(%{typeface: nil, size: size}, opts),
      do: concat(["#Skia.Font<size=", to_doc(size, opts), ">"])

    def inspect(font, opts) do
      concat([
        "#Skia.Font<typeface=",
        to_doc(font.typeface, opts),
        " size=",
        to_doc(font.size, opts),
        ">"
      ])
    end
  end
end
