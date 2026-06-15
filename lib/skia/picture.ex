defmodule Skia.Picture do
  @moduledoc "Recorded Skia picture resource."

  @type t :: %__MODULE__{ref: reference(), width: pos_integer(), height: pos_integer()}
  defstruct [:ref, :width, :height]

  @spec record(Skia.Document.t()) :: {:ok, t()} | {:error, atom(), map()}
  def record(%Skia.Document{} = document), do: Skia.record_picture(document)

  @spec from_bytes(binary(), pos_integer(), pos_integer()) :: {:ok, t()} | {:error, atom()}
  def from_bytes(bytes, width, height) when is_binary(bytes) do
    case Skia.Native.decode_picture(bytes) do
      {:ok, ref} -> {:ok, %__MODULE__{ref: ref, width: width, height: height}}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec to_bytes(t()) :: {:ok, binary()} | {:error, atom()}
  def to_bytes(%__MODULE__{} = picture), do: Skia.Native.encode_picture(picture)
end
