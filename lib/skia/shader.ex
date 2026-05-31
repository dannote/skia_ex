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
