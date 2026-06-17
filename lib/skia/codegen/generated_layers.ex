defmodule Skia.Codegen.GeneratedLayers do
  @moduledoc false

  use RustQ.Meta
  use Skia.Codegen.Defrust

  defmodule Canvas do
    @moduledoc false
    @type t :: term()
  end

  defimpl_handler :draw_save_impl do
    canvas.save()
    :ok
  end

  defimpl_handler :draw_restore_impl do
    canvas.restore()
    :ok
  end
end
