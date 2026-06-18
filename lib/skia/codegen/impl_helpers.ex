defmodule Skia.Codegen.ImplHelpers do
  @moduledoc """
  Shared helpers for Skia-owned Rust impl signatures.

  These helpers intentionally derive Rust paths such as
  `generated_opts::LineOpts<'a>` from Skia command names. Those Rust modules and
  structs are generated/owned by Skia, so this layer must not model them as
  Elixir modules or declare them with `defrustmod`.
  """

  alias RustQ.Rust.AST.TypeBuilder, as: T

  @spec command_impl_args(atom(), atom()) :: keyword()
  def command_impl_args(name, raw_opts_name \\ :_raw_opts) do
    [
      {:canvas, T.ref([:skia_safe, :Canvas])},
      {:opts, generated_opts_type(name)},
      {raw_opts_name, "&[(Atom, Term<'a>)]"}
    ]
  end

  @spec generated_opts_type(atom()) :: RustQ.Rust.AST.TypePath.t()
  def generated_opts_type(name) do
    opts_name =
      name |> Atom.to_string() |> Macro.camelize() |> Kernel.<>("Opts") |> String.to_atom()

    T.path([:generated_opts, opts_name], lifetimes: [:a])
  end

  @spec opts_field_ast(atom()) :: Macro.t()
  def opts_field_ast(field),
    do: {{:., [], [Macro.var(:opts, nil), field]}, [no_parens: true], []}
end
