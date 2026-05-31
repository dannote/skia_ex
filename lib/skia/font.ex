defmodule Skia.Font do
  import Inspect.Algebra

  @moduledoc """
  Decoded typeface resource for text drawing and measurement.
  """

  @type t :: %__MODULE__{ref: term()}

  defstruct [:ref]

  @spec load(binary()) :: {:ok, t()} | {:error, atom()}
  def load(binary) when is_binary(binary) do
    case Skia.Native.load_font(binary) do
      {:ok, ref} -> {:ok, %__MODULE__{ref: ref}}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec load_path(Path.t()) :: {:ok, t()} | {:error, atom() | File.posix()}
  def load_path(path) when is_binary(path) do
    with {:ok, binary} <- File.read(path) do
      load(binary)
    end
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(_font, _opts), do: concat(["#Skia.Font<>"])
  end
end
