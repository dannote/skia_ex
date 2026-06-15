defmodule Skia.Shader.LinearGradient do
  @moduledoc "Linear gradient paint source."

  @type t :: %__MODULE__{from: {float(), float()}, to: {float(), float()}, colors: [term()]}
  defstruct [:from, :to, :colors]
end

defmodule Skia.Shader.RadialGradient do
  @moduledoc "Radial gradient paint source."

  @type t :: %__MODULE__{center: {float(), float()}, radius: float(), colors: [term()]}
  defstruct [:center, :radius, :colors]
end

defmodule Skia.Shader.SweepGradient do
  @moduledoc "Sweep/conic gradient paint source."

  @type t :: %__MODULE__{
          center: {float(), float()},
          start_degrees: float(),
          end_degrees: float(),
          colors: [term()]
        }
  defstruct [:center, :start_degrees, :end_degrees, :colors]
end

defmodule Skia.Shader.ImageShader do
  @moduledoc "Image shader paint source."

  @type t :: %__MODULE__{
          image: Skia.Image.t(),
          tile_x: atom(),
          tile_y: atom(),
          sampling: atom(),
          matrix: tuple() | nil
        }
  defstruct [:image, tile_x: :clamp, tile_y: :clamp, sampling: :linear, matrix: nil]
end

defmodule Skia.Shader.GradientStop do
  @moduledoc "Color stop with explicit position in a gradient."

  @type t :: %__MODULE__{color: term(), position: float()}
  defstruct [:color, :position]
end

defmodule Skia.Paint do
  @moduledoc "Reusable paint description for future paint-focused APIs."

  @type t :: %__MODULE__{
          fill: term(),
          stroke: term(),
          stroke_width: float() | nil,
          blend_mode: atom() | nil
        }
  defstruct [:fill, :stroke, :stroke_width, :blend_mode]
end
