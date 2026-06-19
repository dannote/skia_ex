defmodule Mix.Tasks.Skia.Codegen do
  use Mix.Task

  @shortdoc "Generates Skia command docs and native schema helpers"

  @moduledoc """
  Generates native/schema files derived from `Skia.Codegen.Commands`.

      mix skia.codegen
      mix skia.codegen --check
  """

  @impl true
  def run(args) do
    check? = "--check" in args

    RustQ.Generated.load_manifest!()
    |> RustQ.Generated.sync_all!(
      check: check?,
      command: "mix skia.codegen",
      shell: Mix.shell()
    )
  end
end
