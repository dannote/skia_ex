defmodule Skia.Codegen.Rusty.PaintSupport do
  @moduledoc false

  use RustQ.Meta

  alias RustQ.Type, as: R

  defrustmod(SkiaSafe.Path1DStyle, as: [:skia_safe, :path_1d_path_effect, :Style])

  @spec decode_path_1d_style(R.atom()) ::
          R.nif_result(R.path({:skia_safe, :path_1d_path_effect, :Style}))
  defrust decode_path_1d_style(style) do
    case style do
      :translate -> {:ok, SkiaSafe.Path1DStyle.Translate}
      :rotate -> {:ok, SkiaSafe.Path1DStyle.Rotate}
      :morph -> {:ok, SkiaSafe.Path1DStyle.Morph}
      _ -> {:error, badarg()}
    end
  end
end
