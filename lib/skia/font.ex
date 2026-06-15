defmodule Skia.Font do
  import Inspect.Algebra

  @moduledoc """
  Decoded typeface resource for text drawing and measurement.
  """

  @type t :: %__MODULE__{
          ref: term(),
          family: String.t() | nil,
          weight: integer() | nil,
          slant: atom() | nil
        }

  defstruct [:ref, :family, :weight, :slant]

  @spec load(binary()) :: {:ok, t()} | {:error, atom()}
  def load(binary) when is_binary(binary) do
    case Skia.Native.load_font(binary) do
      {:ok, ref} -> {:ok, %__MODULE__{ref: ref}}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec families() :: {:ok, [String.t()]} | {:error, atom()}
  def families, do: Skia.Native.font_families()

  @spec match(String.t(), keyword()) :: {:ok, t()} | {:error, atom()}
  def match(family, opts \\ []) when is_binary(family) do
    weight = Keyword.get(opts, :weight, 400)
    slant = Keyword.get(opts, :slant, :upright)

    case Skia.Native.match_font(family, weight, slant) do
      {:ok, ref} -> {:ok, %__MODULE__{ref: ref, family: family, weight: weight, slant: slant}}
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

    def inspect(%{family: nil}, _opts), do: concat(["#Skia.Font<>"])

    def inspect(font, opts) do
      concat(["#Skia.Font<family=", to_doc(font.family, opts), ">"])
    end
  end
end
