defmodule Skia.Codegen.Rusty.Support.GeneratedCallables do
  @moduledoc """
  Source-derived callable metadata for helpers implemented in generated Rust.
  """

  alias RustQ.Binding.Callable

  @sources [
    "native/skia_native/src/generated_opts_helpers.rs",
    "native/skia_native/src/generated_path.rs"
  ]
  @names ~w(opt_f32_option build_path)

  @spec __rustq_callables__() :: [Callable.t()]
  def __rustq_callables__ do
    callables =
      @sources
      |> Enum.flat_map(fn source ->
        source |> RustQ.Syn.parse_file!() |> RustQ.Syn.functions()
      end)
      |> Map.new(&{&1.name, Callable.from_syn_function(&1)})

    Enum.map(@names, &Map.fetch!(callables, &1))
  end
end
