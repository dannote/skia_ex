defmodule Skia.Image do
  import Inspect.Algebra

  @moduledoc """
  Decoded image resource for batched drawing.
  """

  @type t :: %__MODULE__{ref: term(), width: pos_integer(), height: pos_integer()}

  defstruct [:ref, :width, :height]

  @spec width(t()) :: pos_integer()
  def width(%__MODULE__{} = image), do: image.width

  @spec height(t()) :: pos_integer()
  def height(%__MODULE__{} = image), do: image.height

  @spec encode(t(), :png | :jpeg | :webp, keyword()) :: {:ok, binary()} | {:error, atom()}
  def encode(%__MODULE__{} = image, format \\ :png, opts \\ [])
      when format in [:png, :jpeg, :webp] do
    Skia.Native.encode_image(image, format, Keyword.get(opts, :quality, 100))
  end

  @spec resize(t(), pos_integer(), pos_integer()) :: {:ok, t()} | {:error, atom()}
  def resize(%__MODULE__{} = image, width, height)
      when is_integer(width) and width > 0 and is_integer(height) and height > 0 do
    case Skia.Native.resize_image(image, width, height) do
      {:ok, ref} -> {:ok, %__MODULE__{ref: ref, width: width, height: height}}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec crop(t(), {number(), number(), number(), number()}) :: {:ok, t()} | {:error, atom()}
  def crop(%__MODULE__{} = image, {x, y, width, height})
      when is_number(x) and is_number(y) and is_number(width) and width > 0 and is_number(height) and
             height > 0 do
    case Skia.Native.crop_image(image, {x * 1.0, y * 1.0, width * 1.0, height * 1.0}) do
      {:ok, ref} -> {:ok, %__MODULE__{ref: ref, width: round(width), height: round(height)}}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec from_picture(Skia.Picture.t(), keyword()) :: {:ok, t()} | {:error, atom()}
  def from_picture(%Skia.Picture{} = picture, opts \\ []) do
    width = Keyword.get(opts, :width, Skia.Picture.width(picture))
    height = Keyword.get(opts, :height, Skia.Picture.height(picture))

    case Skia.canvas(width, height)
         |> Skia.picture(picture)
         |> Skia.to_png() do
      {:ok, png} -> decode(png)
      {:error, reason, _batch} -> {:error, reason}
    end
  end

  @spec decode(binary()) :: {:ok, t()} | {:error, atom()}
  def decode(binary) when is_binary(binary) do
    case Skia.Native.decode_image(binary) do
      {:ok, ref, width, height} -> {:ok, %__MODULE__{ref: ref, width: width, height: height}}
      {:error, reason} -> {:error, reason}
    end
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(image, opts) do
      concat(["#Skia.Image<", to_doc(image.width, opts), "x", to_doc(image.height, opts), ">"])
    end
  end
end
