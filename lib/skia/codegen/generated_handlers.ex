defmodule Skia.Codegen.GeneratedHandlers do
  @moduledoc false

  use RustQ.Meta
  use Skia.Codegen.Defrust

  defmodule Canvas do
    @moduledoc false
    @type t :: term()
  end

  defrustmod(Atoms, as: :atoms)
  defrustmod(GeneratedOpts, as: :generated_opts)

  defhandlers(Skia.Codegen.Defrust.handler_specs())
end
