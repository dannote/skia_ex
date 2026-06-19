defmodule Skia.Codegen.Rusty.PathSupport do
  @moduledoc false

  use RustQ.Meta

  alias RustQ.Type, as: R

  @spec decode_path_direction(R.atom()) :: R.nif_result(R.path(:PathDirection))
  defrust decode_path_direction(value) do
    case value do
      :cw -> {:ok, PathDirection.CW}
      :ccw -> {:ok, PathDirection.CCW}
      _ -> {:error, badarg()}
    end
  end
end
