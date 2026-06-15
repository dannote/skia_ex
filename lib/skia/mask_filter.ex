defmodule Skia.MaskFilter do
  @moduledoc "Mask filters transform draw masks before painting."

  defmodule Blur do
    @moduledoc "Blur mask filter."

    @type t :: %__MODULE__{style: atom(), sigma: float(), respect_ctm: boolean()}
    defstruct [:style, :sigma, respect_ctm: true]
  end

  @type t :: Blur.t()

  @doc "Creates a blur mask filter."
  @spec blur(number(), keyword()) :: Blur.t()
  def blur(sigma, opts \\ []) when is_number(sigma) do
    %Blur{
      style: Keyword.get(opts, :style, :normal),
      sigma: :erlang.float(sigma),
      respect_ctm: Keyword.get(opts, :respect_ctm, true)
    }
  end
end
