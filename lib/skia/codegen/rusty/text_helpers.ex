defmodule Skia.Codegen.Rusty.TextHelpers do
  @moduledoc false

  use RustQ.Meta

  alias RustQ.Type, as: R

  @spec generated_asts() :: [RustQ.Rust.AST.Function.t()]
  def generated_asts, do: __rustq_asts__()

  @spec decode_text_align(R.atom()) :: R.nif_result(R.path(:TextAlign))
  defrust decode_text_align(value) do
    case value do
      :center -> {:ok, TextAlign.Center}
      :right -> {:ok, TextAlign.Right}
      :justify -> {:ok, TextAlign.Justify}
      :left -> {:ok, TextAlign.Left}
      _ -> {:error, badarg()}
    end
  end

  @spec decode_text_direction(R.atom()) :: R.nif_result(R.path(:TextDirection))
  defrust decode_text_direction(value) do
    case value do
      :rtl -> {:ok, TextDirection.RTL}
      :ltr -> {:ok, TextDirection.LTR}
      _ -> {:error, badarg()}
    end
  end
end
