defmodule Skia.Codegen.GeneratedHandlers do
  @moduledoc false

  use Skia.Codegen.Defrust

  defhandlers(from: Skia.CommandSpec.all(), except: [:save, :restore])
end
