defmodule Skia.ColorFilter do
  @moduledoc "Color filter values for paint and image filters."

  defmodule Blend do
    @moduledoc "Blend a constant color into source colors using a blend mode."
    @type t :: %__MODULE__{color: term(), blend_mode: atom()}
    defstruct [:color, blend_mode: :src_in]
  end

  defmodule Matrix do
    @moduledoc "20-value row-major color matrix filter."
    @type t :: %__MODULE__{matrix: [float()], clamp: boolean()}
    defstruct [:matrix, clamp: true]
  end

  defmodule Compose do
    @moduledoc "Color filter composition: `outer(inner(color))`."
    @type t :: %__MODULE__{outer: Skia.ColorFilter.t(), inner: Skia.ColorFilter.t()}
    defstruct [:outer, :inner]
  end

  @type t :: Blend.t() | Matrix.t() | Compose.t()

  @spec blend(term(), atom()) :: Blend.t()
  def blend(color, blend_mode \\ :src_in), do: %Blend{color: color, blend_mode: blend_mode}

  @spec matrix([number()], keyword()) :: Matrix.t()
  def matrix(values, opts \\ []) when is_list(values) do
    matrix = Enum.map(values, &:erlang.float/1)

    case matrix do
      [_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _] ->
        %Matrix{matrix: matrix, clamp: Keyword.get(opts, :clamp, true)}

      _ ->
        raise ArgumentError, "color filter matrix must contain 20 values"
    end
  end

  @spec compose(t(), t()) :: Compose.t()
  def compose(outer, inner), do: %Compose{outer: outer, inner: inner}
end
