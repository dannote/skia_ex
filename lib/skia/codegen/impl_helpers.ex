defmodule Skia.Codegen.ImplHelpers do
  @moduledoc false

  alias RustQ.Rust.AST.Builder, as: A

  @spec command_impl_args(atom(), atom()) :: keyword()
  def command_impl_args(name, raw_opts_name \\ :_raw_opts) do
    [
      {:canvas, A.ref_type([:skia_safe, :Canvas])},
      {:opts, generated_opts_type(name)},
      {raw_opts_name, "&[(Atom, Term<'a>)]"}
    ]
  end

  @spec generated_opts_type(atom()) :: RustQ.Rust.AST.TypePath.t()
  def generated_opts_type(name) do
    opts_name =
      name |> Atom.to_string() |> Macro.camelize() |> Kernel.<>("Opts") |> String.to_atom()

    A.type_path([:generated_opts, opts_name], lifetimes: [:a])
  end

  @spec opts_field_ast(atom()) :: Macro.t()
  def opts_field_ast(field),
    do: {{:., [], [Macro.var(:opts, nil), field]}, [no_parens: true], []}
end
