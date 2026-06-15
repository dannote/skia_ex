defmodule Skia.ImageFilter do
  @moduledoc "Image filter values for layers and paints."

  defmodule Blur do
    @moduledoc "Gaussian blur image filter."

    @type t :: %__MODULE__{sigma_x: float(), sigma_y: float(), tile_mode: atom()}
    defstruct [:sigma_x, :sigma_y, tile_mode: :decal]
  end

  @type t :: Blur.t()

  @doc "Creates a Gaussian blur image filter."
  @spec blur(number(), keyword()) :: Blur.t()
  def blur(sigma, opts \\ []) when is_number(sigma) do
    blur(sigma, sigma, opts)
  end

  @doc "Creates a Gaussian blur image filter with separate x/y sigma values."
  @spec blur(number(), number(), keyword()) :: Blur.t()
  def blur(sigma_x, sigma_y, opts) when is_number(sigma_x) and is_number(sigma_y) do
    %Blur{
      sigma_x: sigma_x * 1.0,
      sigma_y: sigma_y * 1.0,
      tile_mode: Keyword.get(opts, :tile, :decal)
    }
  end
end
