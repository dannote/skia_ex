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

  @spec optional_matrix_from_term(R.term()) :: R.nif_result(R.option(R.path(:Matrix)))
  defrust optional_matrix_from_term(matrix_term) do
    case decode_as(matrix_term, R.atom()) do
      {:ok, atom} ->
        if atom == Atoms.nil() do
          {:ok, none()}
        else
          {:ok, some(unwrap!(matrix_from_term(matrix_term)))}
        end

      {:error, _reason} ->
        {:ok, some(unwrap!(matrix_from_term(matrix_term)))}
    end
  end
end
