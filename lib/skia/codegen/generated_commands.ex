defmodule Skia.Codegen.GeneratedCommands do
  @moduledoc false

  use RustQ.Meta
  use Skia.Codegen.Defrust

  defmodule Canvas do
    @moduledoc false
    @type t :: term()
  end

  defcommands(from: Skia.CommandSpec.Layers.commands(), only: [:save, :restore])
end
