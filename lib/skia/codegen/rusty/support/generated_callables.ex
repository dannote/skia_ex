defmodule Skia.Codegen.Rusty.Support.GeneratedCallables do
  @moduledoc """
  Callable metadata for generated Rust helpers that are available in generated modules.

  These callables are implemented in generated Rust support files, not as Rusty
  Elixir functions in this module. Keeping their signatures here gives RustQ
  inference structural metadata without adding fake runtime helper definitions to
  command/support modules.
  """

  alias RustQ.Binding.Callable
  alias RustQ.Type, as: R

  @spec __rustq_callables__() :: [Callable.t()]
  def __rustq_callables__ do
    [
      callable(
        :opt_f32_option,
        [quote(do: R.slice({atom(), term()})), quote(do: atom())],
        quote(do: R.nif_result(R.option(R.f32())))
      ),
      callable(
        :build_path,
        [quote(do: term())],
        quote(do: R.nif_result(R.path({:skia_safe, :Path})))
      )
    ]
  end

  defp callable(name, args, return) do
    Callable.from_spec(name, Enum.map(args, &RustQ.Spec.type/1), RustQ.Spec.type(return))
  end
end
