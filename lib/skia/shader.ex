defmodule Skia.Shader.LinearGradient do
  @moduledoc "Linear gradient paint source."

  @type t :: %__MODULE__{
          from: {float(), float()},
          to: {float(), float()},
          colors: [term()],
          tile_mode: atom(),
          matrix: tuple() | nil
        }
  defstruct [:from, :to, :colors, tile_mode: :clamp, matrix: nil]
end

defmodule Skia.Shader.RadialGradient do
  @moduledoc "Radial gradient paint source."

  @type t :: %__MODULE__{
          center: {float(), float()},
          radius: float(),
          colors: [term()],
          tile_mode: atom(),
          matrix: tuple() | nil
        }
  defstruct [:center, :radius, :colors, tile_mode: :clamp, matrix: nil]
end

defmodule Skia.Shader.TwoPointConicalGradient do
  @moduledoc "Two-point conical gradient paint source."

  @type t :: %__MODULE__{
          start: {float(), float()},
          start_radius: float(),
          end: {float(), float()},
          end_radius: float(),
          colors: [term()],
          tile_mode: atom(),
          matrix: tuple() | nil
        }
  defstruct [:start, :start_radius, :end, :end_radius, :colors, tile_mode: :clamp, matrix: nil]
end

defmodule Skia.Shader.ColorShader do
  @moduledoc "Solid color shader paint source."

  @type t :: %__MODULE__{color: term()}
  defstruct [:color]
end

defmodule Skia.Shader.SweepGradient do
  @moduledoc "Sweep/conic gradient paint source."

  @type t :: %__MODULE__{
          center: {float(), float()},
          start_degrees: float(),
          end_degrees: float(),
          colors: [term()],
          tile_mode: atom(),
          matrix: tuple() | nil
        }
  defstruct [:center, :start_degrees, :end_degrees, :colors, tile_mode: :clamp, matrix: nil]
end

defmodule Skia.Shader.ImageShader do
  @moduledoc "Image shader paint source."

  @type t :: %__MODULE__{
          image: Skia.Image.t(),
          tile_x: atom(),
          tile_y: atom(),
          sampling: atom() | Skia.SamplingOptions.t(),
          matrix: tuple() | nil
        }
  defstruct [:image, tile_x: :clamp, tile_y: :clamp, sampling: :linear, matrix: nil]
end

defmodule Skia.Shader.PictureShader do
  @moduledoc "Picture shader paint source."

  @type t :: %__MODULE__{
          picture: Skia.Picture.t(),
          tile_x: atom(),
          tile_y: atom(),
          filter: atom(),
          matrix: tuple() | nil,
          tile_rect: tuple() | nil
        }
  defstruct [
    :picture,
    tile_x: :clamp,
    tile_y: :clamp,
    filter: :linear,
    matrix: nil,
    tile_rect: nil
  ]
end

defmodule Skia.Shader.GradientStop do
  @moduledoc "Color stop with explicit position in a gradient."

  @type t :: %__MODULE__{color: term(), position: float()}
  defstruct [:color, :position]
end

defmodule Skia.Shader do
  @moduledoc "Reusable shader paint sources."

  @doc "Creates a linear gradient paint value."
  @spec linear_gradient({number(), number()}, {number(), number()}, [term()], keyword()) ::
          Skia.Shader.LinearGradient.t()
  def linear_gradient(from, to, colors, opts \\ []),
    do: %Skia.Shader.LinearGradient{
      from: from,
      to: to,
      colors: colors,
      tile_mode: Keyword.get(opts, :tile, Keyword.get(opts, :tile_mode, :clamp)),
      matrix: Keyword.get(opts, :matrix)
    }

  @doc "Creates a two-point conical gradient paint value."
  @spec two_point_conical_gradient(
          {number(), number()},
          number(),
          {number(), number()},
          number(),
          [term()],
          keyword()
        ) :: Skia.Shader.TwoPointConicalGradient.t()
  def two_point_conical_gradient(start, start_radius, finish, end_radius, colors, opts \\ []) do
    %Skia.Shader.TwoPointConicalGradient{
      start: start,
      start_radius: start_radius,
      end: finish,
      end_radius: end_radius,
      colors: colors,
      tile_mode: Keyword.get(opts, :tile, Keyword.get(opts, :tile_mode, :clamp)),
      matrix: Keyword.get(opts, :matrix)
    }
  end

  @doc "Creates a solid-color shader paint value."
  @spec color(term()) :: Skia.Shader.ColorShader.t()
  def color(color), do: %Skia.Shader.ColorShader{color: color}

  @doc "Creates a radial gradient paint value."
  @spec radial_gradient({number(), number()}, number(), [term()], keyword()) ::
          Skia.Shader.RadialGradient.t()
  def radial_gradient(center, radius, colors, opts \\ []),
    do: %Skia.Shader.RadialGradient{
      center: center,
      radius: radius,
      colors: colors,
      tile_mode: Keyword.get(opts, :tile, Keyword.get(opts, :tile_mode, :clamp)),
      matrix: Keyword.get(opts, :matrix)
    }

  @doc "Creates a sweep/conic gradient paint value."
  @spec sweep_gradient({number(), number()}, number(), number(), [term()], keyword()) ::
          Skia.Shader.SweepGradient.t()
  def sweep_gradient(center, start_degrees, end_degrees, colors, opts \\ []) do
    %Skia.Shader.SweepGradient{
      center: center,
      start_degrees: start_degrees,
      end_degrees: end_degrees,
      colors: colors,
      tile_mode: Keyword.get(opts, :tile, Keyword.get(opts, :tile_mode, :clamp)),
      matrix: Keyword.get(opts, :matrix)
    }
  end

  @doc "Creates a positioned gradient stop."
  @spec stop(term(), number()) :: Skia.Shader.GradientStop.t()
  def stop(color, position), do: %Skia.Shader.GradientStop{color: color, position: position}

  @doc "Creates an image shader paint value."
  @spec image(Skia.Image.t(), keyword()) :: Skia.Shader.ImageShader.t()
  def image(%Skia.Image{} = image, opts \\ []) do
    %Skia.Shader.ImageShader{
      image: image,
      tile_x: shader_tile(opts) |> elem(0),
      tile_y: shader_tile(opts) |> elem(1),
      sampling: Keyword.get(opts, :sampling, :linear),
      matrix: Keyword.get(opts, :matrix)
    }
  end

  @doc "Creates a picture shader paint value."
  @spec picture(Skia.Picture.t(), keyword()) :: Skia.Shader.PictureShader.t()
  def picture(%Skia.Picture{} = picture, opts \\ []) do
    %Skia.Shader.PictureShader{
      picture: picture,
      tile_x: shader_tile(opts) |> elem(0),
      tile_y: shader_tile(opts) |> elem(1),
      filter: Keyword.get(opts, :filter, :linear),
      matrix: Keyword.get(opts, :matrix),
      tile_rect: Keyword.get(opts, :tile_rect)
    }
  end

  defp shader_tile(opts) do
    case Keyword.get(opts, :tile) do
      nil -> {Keyword.get(opts, :tile_x, :clamp), Keyword.get(opts, :tile_y, :clamp)}
      {tile_x, tile_y} -> {tile_x, tile_y}
      tile when is_atom(tile) -> {tile, tile}
    end
  end
end

defmodule Skia.Paint do
  @moduledoc "Reusable paint description for future paint-focused APIs."

  @type t :: %__MODULE__{
          fill: term(),
          stroke: term(),
          stroke_width: float() | nil,
          blend_mode: atom() | nil,
          image_filter: Skia.ImageFilter.t() | nil,
          path_effect: Skia.PathEffect.t() | nil,
          color_filter: Skia.ColorFilter.t() | nil
        }
  defstruct [
    :fill,
    :stroke,
    :stroke_width,
    :blend_mode,
    :image_filter,
    :path_effect,
    :color_filter
  ]

  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    struct(
      __MODULE__,
      Keyword.take(opts, [
        :fill,
        :stroke,
        :stroke_width,
        :blend_mode,
        :image_filter,
        :path_effect,
        :color_filter
      ])
    )
  end

  @spec to_opts(t()) :: keyword()
  def to_opts(%__MODULE__{} = paint) do
    paint
    |> Map.from_struct()
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end
end
