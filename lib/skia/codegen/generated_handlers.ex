defmodule Skia.Codegen.GeneratedHandlers do
  @moduledoc false

  use RustQ.Meta
  use Skia.Codegen.Rusty

  defmodule Canvas do
    @moduledoc false
    @type t :: term()
  end

  defhandlers(Skia.Codegen.Rusty.handler_specs())
end
