defmodule Skia.ImageFilter do
  @moduledoc "Image filter values for layers and paints."

  defmodule Blur do
    @moduledoc "Gaussian blur image filter."
    @type t :: %__MODULE__{sigma_x: float(), sigma_y: float(), tile_mode: atom()}
    defstruct [:sigma_x, :sigma_y, tile_mode: :decal]
  end

  defmodule Compose do
    @moduledoc "Image filter composition: `outer(inner(source))`."
    @type t :: %__MODULE__{outer: Skia.ImageFilter.t(), inner: Skia.ImageFilter.t()}
    defstruct [:outer, :inner]
  end

  defmodule Offset do
    @moduledoc "Offset image filter."
    @type t :: %__MODULE__{x: float(), y: float(), input: Skia.ImageFilter.t() | nil}
    defstruct [:x, :y, :input]
  end

  defmodule DropShadow do
    @moduledoc "Drop-shadow image filter."
    @type t :: %__MODULE__{
            dx: float(),
            dy: float(),
            sigma_x: float(),
            sigma_y: float(),
            color: term(),
            input: Skia.ImageFilter.t() | nil,
            shadow_only: boolean()
          }
    defstruct [:dx, :dy, :sigma_x, :sigma_y, :color, :input, shadow_only: false]
  end

  defmodule ColorFilter do
    @moduledoc "Image filter that applies a color filter to its input."
    @type t :: %__MODULE__{color_filter: Skia.ColorFilter.t(), input: Skia.ImageFilter.t() | nil}
    defstruct [:color_filter, :input]
  end

  defmodule Shader do
    @moduledoc "Image filter that fills with a shader."
    @type t :: %__MODULE__{shader: term()}
    defstruct [:shader]
  end

  defmodule Magnifier do
    @moduledoc "Magnifier image filter."
    @type t :: %__MODULE__{
            bounds: tuple(),
            zoom: float(),
            inset: float(),
            sampling: term(),
            input: Skia.ImageFilter.t() | nil
          }
    defstruct [:bounds, :zoom, :inset, sampling: :linear, input: nil]
  end

  defmodule MatrixConvolution do
    @moduledoc "Matrix convolution image filter."
    @type t :: %__MODULE__{
            kernel_size: {integer(), integer()},
            kernel: [float()],
            gain: float(),
            bias: float(),
            offset: {integer(), integer()},
            tile: atom(),
            convolve_alpha: boolean(),
            input: Skia.ImageFilter.t() | nil
          }
    defstruct [
      :kernel_size,
      :kernel,
      gain: 1.0,
      bias: 0.0,
      offset: {0, 0},
      tile: :clamp,
      convolve_alpha: true,
      input: nil
    ]
  end

  defmodule MatrixTransform do
    @moduledoc "Matrix transform image filter."
    @type t :: %__MODULE__{
            matrix: Skia.Matrix.t(),
            sampling: term(),
            input: Skia.ImageFilter.t() | nil
          }
    defstruct [:matrix, sampling: :linear, input: nil]
  end

  defmodule Merge do
    @moduledoc "Merge image filters using source-over."
    @type t :: %__MODULE__{filters: [Skia.ImageFilter.t() | nil]}
    defstruct [:filters]
  end

  defmodule Tile do
    @moduledoc "Tile image filter."
    @type t :: %__MODULE__{src: tuple(), dst: tuple(), input: Skia.ImageFilter.t() | nil}
    defstruct [:src, :dst, input: nil]
  end

  defmodule Morphology do
    @moduledoc "Dilate/erode morphology image filter."
    @type t :: %__MODULE__{
            op: :dilate | :erode,
            radius_x: float(),
            radius_y: float(),
            input: Skia.ImageFilter.t() | nil
          }
    defstruct [:op, :radius_x, :radius_y, :input]
  end

  @type t ::
          Blur.t()
          | Compose.t()
          | Offset.t()
          | DropShadow.t()
          | ColorFilter.t()
          | Shader.t()
          | Magnifier.t()
          | MatrixConvolution.t()
          | MatrixTransform.t()
          | Merge.t()
          | Tile.t()
          | Morphology.t()

  @doc "Creates a Gaussian blur image filter."
  @spec blur(number(), keyword()) :: Blur.t()
  def blur(sigma, opts \\ []) when is_number(sigma), do: blur(sigma, sigma, opts)

  @doc "Creates a Gaussian blur image filter with separate x/y sigma values."
  @spec blur(number(), number(), keyword()) :: Blur.t()
  def blur(sigma_x, sigma_y, opts) when is_number(sigma_x) and is_number(sigma_y) do
    %Blur{
      sigma_x: sigma_x * 1.0,
      sigma_y: sigma_y * 1.0,
      tile_mode: Keyword.get(opts, :tile, :decal)
    }
  end

  @doc "Composes image filters as `outer(inner(source))`."
  @spec compose(t(), t()) :: Compose.t()
  def compose(outer, inner), do: %Compose{outer: outer, inner: inner}

  @doc "Creates an offset image filter."
  @spec offset(number(), number(), keyword()) :: Offset.t()
  def offset(x, y, opts \\ []) when is_number(x) and is_number(y) do
    %Offset{x: x * 1.0, y: y * 1.0, input: Keyword.get(opts, :input)}
  end

  @doc "Creates a drop-shadow image filter."
  @spec drop_shadow({number(), number()}, number() | {number(), number()}, term(), keyword()) ::
          DropShadow.t()
  def drop_shadow({dx, dy}, sigma, color, opts \\ []) do
    {sigma_x, sigma_y} = sigma_pair(sigma)

    %DropShadow{
      dx: dx * 1.0,
      dy: dy * 1.0,
      sigma_x: sigma_x,
      sigma_y: sigma_y,
      color: color,
      input: Keyword.get(opts, :input),
      shadow_only: Keyword.get(opts, :shadow_only, false)
    }
  end

  @doc "Creates an image filter that applies a color filter."
  @spec color_filter(Skia.ColorFilter.t(), keyword()) :: ColorFilter.t()
  def color_filter(color_filter, opts \\ []) do
    %ColorFilter{color_filter: color_filter, input: Keyword.get(opts, :input)}
  end

  @doc "Creates an image filter from a shader/paint source."
  @spec shader(term()) :: Shader.t()
  def shader(shader), do: %Shader{shader: shader}

  @doc "Creates a magnifier image filter."
  @spec magnifier(tuple(), number(), number(), keyword()) :: Magnifier.t()
  def magnifier(bounds, zoom, inset, opts \\ []) do
    %Magnifier{
      bounds: bounds,
      zoom: zoom * 1.0,
      inset: inset * 1.0,
      sampling: Keyword.get(opts, :sampling, :linear),
      input: Keyword.get(opts, :input)
    }
  end

  @doc "Creates a matrix convolution image filter."
  @spec matrix_convolution({integer(), integer()}, [number()], keyword()) :: MatrixConvolution.t()
  def matrix_convolution(kernel_size, kernel, opts \\ []) do
    %MatrixConvolution{
      kernel_size: kernel_size,
      kernel: Enum.map(kernel, &:erlang.float/1),
      gain: :erlang.float(Keyword.get(opts, :gain, 1.0)),
      bias: :erlang.float(Keyword.get(opts, :bias, 0.0)),
      offset: Keyword.get(opts, :offset, {0, 0}),
      tile: Keyword.get(opts, :tile, :clamp),
      convolve_alpha: Keyword.get(opts, :convolve_alpha, true),
      input: Keyword.get(opts, :input)
    }
  end

  @doc "Creates a matrix transform image filter."
  @spec matrix_transform(Skia.Matrix.t(), keyword()) :: MatrixTransform.t()
  def matrix_transform(matrix, opts \\ []) do
    %MatrixTransform{
      matrix: matrix,
      sampling: Keyword.get(opts, :sampling, :linear),
      input: Keyword.get(opts, :input)
    }
  end

  @doc "Merges image filters using source-over."
  @spec merge([t() | nil]) :: Merge.t()
  def merge(filters), do: %Merge{filters: filters}

  @doc "Creates a tile image filter."
  @spec tile(tuple(), tuple(), keyword()) :: Tile.t()
  def tile(src, dst, opts \\ []), do: %Tile{src: src, dst: dst, input: Keyword.get(opts, :input)}

  @doc "Creates a dilate image filter."
  @spec dilate(number() | {number(), number()}, keyword()) :: Morphology.t()
  def dilate(radius, opts \\ []), do: morphology(:dilate, radius, opts)

  @doc "Creates an erode image filter."
  @spec erode(number() | {number(), number()}, keyword()) :: Morphology.t()
  def erode(radius, opts \\ []), do: morphology(:erode, radius, opts)

  defp morphology(op, radius, opts) do
    {radius_x, radius_y} = sigma_pair(radius)
    %Morphology{op: op, radius_x: radius_x, radius_y: radius_y, input: Keyword.get(opts, :input)}
  end

  defp sigma_pair({x, y}) when is_number(x) and is_number(y), do: {x * 1.0, y * 1.0}
  defp sigma_pair(value) when is_number(value), do: {value * 1.0, value * 1.0}
end
