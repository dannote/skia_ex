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
      {:ok, ref, family} -> {:ok, %__MODULE__{ref: ref, family: family}}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec load_path(Path.t()) :: {:ok, t()} | {:error, atom() | File.posix()}
  def load_path(path) when is_binary(path) do
    with {:ok, binary} <- File.read(path), do: load(binary)
  end

  @spec families() :: {:ok, [String.t()]} | {:error, atom()}
  def families, do: Skia.Native.font_families()

  @doc """
  Matches an installed typeface capable of rendering one Unicode character.

  The optional `:family`, `:weight`, `:slant`, and `:languages` values map
  directly to Skia's font-manager matching inputs. An empty family allows Skia
  to select any installed family.
  """
  @spec match_character(String.t() | non_neg_integer(), keyword()) ::
          {:ok, t()} | {:error, atom()}
  def match_character(character, opts \\ []) when is_list(opts) do
    family = Keyword.get(opts, :family, "")
    weight = Keyword.get(opts, :weight, 400)
    slant = Keyword.get(opts, :slant, :upright)
    languages = Keyword.get(opts, :languages, [])

    with {:ok, character} <- unicode_value(character),
         true <- is_binary(family) and is_integer(weight) and is_list(languages),
         true <- Enum.all?(languages, &is_binary/1) do
      case Skia.Native.match_font_character(family, weight, slant, languages, character) do
        {:ok, ref, matched_family} ->
          {:ok,
           %__MODULE__{
             ref: ref,
             family: matched_family,
             weight: weight,
             slant: slant
           }}

        {:error, reason} ->
          {:error, reason}
      end
    else
      false -> {:error, :invalid_font_match_options}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec info(t()) :: {:ok, map()} | {:error, atom()}
  def info(%__MODULE__{} = typeface) do
    case Skia.Native.typeface_info(typeface) do
      {:ok, {id, weight, width, slant, bold?, italic?, fixed_pitch?}} ->
        {:ok,
         %{
           id: id,
           weight: weight,
           width: width,
           slant: slant,
           bold?: bold?,
           italic?: italic?,
           fixed_pitch?: fixed_pitch?
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec match_family(String.t(), keyword()) :: {:ok, t()} | {:error, atom()}
  def match_family(family, opts \\ []) when is_binary(family) do
    weight = Keyword.get(opts, :weight, 400)
    slant = Keyword.get(opts, :slant, :upright)

    case Skia.Native.match_font(family, weight, slant) do
      {:ok, ref} -> {:ok, %__MODULE__{ref: ref, family: family, weight: weight, slant: slant}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp unicode_value(<<character::utf8>>), do: {:ok, character}

  defp unicode_value(character)
       when is_integer(character) and character in 0..0x10FFFF and
              character not in 0xD800..0xDFFF,
       do: {:ok, character}

  defp unicode_value(_character), do: {:error, :invalid_character}

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(%{family: nil}, _opts), do: concat(["#Skia.Typeface<>"])

    def inspect(typeface, opts) do
      concat(["#Skia.Typeface<family=", to_doc(typeface.family, opts), ">"])
    end
  end
end
