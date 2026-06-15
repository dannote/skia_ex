defmodule Skia.Picture do
  import Inspect.Algebra

  @moduledoc "Recorded Skia picture resource."

  @type cull_rect :: {float(), float(), float(), float()}

  @type t :: %__MODULE__{ref: reference(), width: pos_integer(), height: pos_integer()}
  defstruct [:ref, :width, :height]

  @spec record(Skia.Document.t()) :: {:ok, t()} | {:error, atom(), map()}
  def record(%Skia.Document{} = document), do: Skia.record_picture(document)

  @spec from_bytes(binary(), pos_integer(), pos_integer()) :: {:ok, t()} | {:error, atom()}
  def from_bytes(bytes, width, height)
      when is_binary(bytes) and is_integer(width) and width > 0 and is_integer(height) and
             height > 0 do
    case Skia.Native.decode_picture(bytes) do
      {:ok, ref} -> {:ok, %__MODULE__{ref: ref, width: width, height: height}}
      {:error, reason} -> {:error, reason}
    end
  end

  def from_bytes(_bytes, _width, _height), do: {:error, :invalid_picture}

  @spec to_bytes(t()) :: {:ok, binary()} | {:error, atom()}
  def to_bytes(%__MODULE__{} = picture), do: Skia.Native.encode_picture(picture)

  @spec width(t()) :: pos_integer()
  def width(%__MODULE__{width: width}), do: width

  @spec height(t()) :: pos_integer()
  def height(%__MODULE__{height: height}), do: height

  @spec info(t()) ::
          {:ok,
           %{
             cull_rect: cull_rect(),
             op_count: non_neg_integer(),
             nested_op_count: non_neg_integer(),
             bytes_used: non_neg_integer()
           }}
          | {:error, atom()}
  def info(%__MODULE__{} = picture) do
    case Skia.Native.picture_info(picture) do
      {:ok, {left, top, right, bottom, op_count, nested_op_count, bytes_used}} ->
        {:ok,
         %{
           cull_rect: {left, top, right, bottom},
           op_count: op_count,
           nested_op_count: nested_op_count,
           bytes_used: bytes_used
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(picture, opts) do
      concat([
        "#Skia.Picture<",
        to_doc(picture.width, opts),
        "x",
        to_doc(picture.height, opts),
        ">"
      ])
    end
  end
end
