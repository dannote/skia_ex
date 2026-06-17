defmodule Skia.Codegen.GeneratedCommands do
  @moduledoc false

  use RustQ.Meta
  use Skia.Codegen.Defrust

  defmodule Canvas do
    @moduledoc false
    @type t :: term()
  end

  defcommand :save do
    handler(:draw_save)

    impl do
      canvas.save()
      :ok
    end
  end
end
