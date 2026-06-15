defmodule Skia.TextBlob do
  import Inspect.Algebra

  @moduledoc "Immutable shaped text blob resource for repeated text drawing."

  @type t :: %__MODULE__{ref: reference(), text: String.t(), size: float()}
  defstruct [:ref, :text, :size]

  @spec new(String.t(), keyword()) :: {:ok, t()} | {:error, atom()}
  def new(text, opts \\ []) when is_binary(text) do
    font = Keyword.get(opts, :font)
    size = Keyword.get(opts, :size, 16)

    case Skia.Native.create_text_blob(text, font, size) do
      {:ok, ref} -> {:ok, %__MODULE__{ref: ref, text: text, size: blob_size(font, size)}}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec bounds(t()) :: {:ok, {float(), float(), float(), float()}} | {:error, atom()}
  def bounds(%__MODULE__{} = blob), do: Skia.Native.text_blob_bounds(blob)

  defp blob_size(%Skia.Font{size: size}, _size) when is_number(size), do: size
  defp blob_size(_font, size), do: :erlang.float(size)

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(blob, opts) do
      concat([
        "#Skia.TextBlob<size=",
        to_doc(blob.size, opts),
        " text=",
        to_doc(blob.text, opts),
        ">"
      ])
    end
  end
end
