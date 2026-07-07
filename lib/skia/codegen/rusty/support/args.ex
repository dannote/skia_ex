defmodule Skia.Codegen.Rusty.Support.Args do
  @moduledoc """
  Rusty Elixir helpers for decoded command argument vectors.
  """

  defmacro __using__(_opts) do
    quote do
      import Skia.Codegen.Rusty.Support.Args
    end
  end

  defmacro first_arg_term! do
    quote do
      deref(unwrap!(var!(args).first().ok_or(badarg())))
    end
  end

  defmacro arg_term!(index) do
    quote do
      deref(unwrap!(var!(args).get(unquote(index)).ok_or(badarg())))
    end
  end
end
