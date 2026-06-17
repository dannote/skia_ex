defmodule Skia.Codegen.GeneratedHandlers do
  @moduledoc false

  use RustQ.Meta
  use Skia.Codegen.Defrust

  defmodule Canvas do
    @moduledoc false
    @type t :: term()
  end

  defhandlers(from: Skia.CommandSpec.all(), except: [:save, :restore])
end
