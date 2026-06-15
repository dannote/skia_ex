defmodule Skia.Typeface do
  import Inspect.Algebra

  @moduledoc """
  Typeface resource independent of font size.

      {:ok, families} = Skia.Typeface.families()
      {:ok, typeface} = Skia.Typeface.match_family("Inter", weight: 700)
      font = Skia.Font.new(typeface, size: 18)
  """

  @type t :: %__MODULE__{
          ref: reference(),
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

  @spec load_path(Path.t()) :: {:ok, t()} | {:error, atom() | File.posix()}
  def load_path(path) when is_binary(path) do
    with {:ok, binary} <- File.read(path), do: load(binary)
  end

  @spec families() :: {:ok, [String.t()]} | {:error, atom()}
  def families, do: Skia.Native.font_families()

  @spec match_family(String.t(), keyword()) :: {:ok, t()} | {:error, atom()}
  def match_family(family, opts \\ []) when is_binary(family) do
    weight = Keyword.get(opts, :weight, 400)
    slant = Keyword.get(opts, :slant, :upright)

    case Skia.Native.match_font(family, weight, slant) do
      {:ok, ref} -> {:ok, %__MODULE__{ref: ref, family: family, weight: weight, slant: slant}}
      {:error, reason} -> {:error, reason}
    end
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(%{family: nil}, _opts), do: concat(["#Skia.Typeface<>"])

    def inspect(typeface, opts) do
      concat(["#Skia.Typeface<family=", to_doc(typeface.family, opts), ">"])
    end
  end
end
