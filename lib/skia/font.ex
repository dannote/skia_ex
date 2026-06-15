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

  @spec metrics(t()) :: {:ok, map()} | {:error, atom()}
  def metrics(%__MODULE__{} = font) do
    case Skia.Native.font_metrics(font) do
      {:ok,
       [
         line_spacing,
         top,
         ascent,
         descent,
         bottom,
         leading,
         avg_char_width,
         max_char_width,
         x_min,
         x_max,
         x_height,
         cap_height
       ]} ->
        {:ok,
         %{
           line_spacing: line_spacing,
           top: top,
           ascent: ascent,
           descent: descent,
           bottom: bottom,
           leading: leading,
           avg_char_width: avg_char_width,
           max_char_width: max_char_width,
           x_min: x_min,
           x_max: x_max,
           x_height: x_height,
           cap_height: cap_height
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec glyph_ids(t(), String.t()) :: {:ok, [non_neg_integer()]} | {:error, atom()}
  def glyph_ids(%__MODULE__{} = font, text) when is_binary(text),
    do: Skia.Native.font_glyph_ids(font, text)

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
