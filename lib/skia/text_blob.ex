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
      {:ok, ref} -> {:ok, %__MODULE__{ref: ref, text: text, size: :erlang.float(size)}}
      {:error, reason} -> {:error, reason}
    end
  end

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
