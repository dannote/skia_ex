defmodule Skia.Command.Registry do
  @moduledoc false
  @compile {:no_warn_undefined,
            [
              {Skia.Codegen.Command.Registry, :doc, 2},
              {Skia.Codegen.Command.Registry, :fetch!, 1}
            ]}

  @registry_path Application.app_dir(:skia, "priv/command_registry.etf")
  @external_resource @registry_path
  # Generated build artifact, packaged with Skia and never sourced from user input.
  # sobelow_skip ["BinToTerm"]
  @commands @registry_path |> File.read!() |> :erlang.binary_to_term()
  @non_drawable ~w(save save_layer restore translate scale rotate rotate_at concat push_style pop_style)a

  @spec all() :: keyword()
  def all, do: @commands

  @spec names() :: [atom()]
  def names, do: Keyword.keys(@commands)

  @spec drawable_names() :: [atom()]
  def drawable_names, do: names() -- @non_drawable

  @spec fetch!(atom()) :: keyword()
  def fetch!(name), do: Keyword.fetch!(@commands, name)

  @spec doc(atom(), keyword()) :: String.t()
  def doc(name, spec) do
    codegen_registry = Skia.Codegen.Command.Registry

    case Code.ensure_compiled(codegen_registry) do
      {:module, ^codegen_registry} ->
        codegen_registry.doc(name, codegen_registry.fetch!(name))

      {:error, _reason} ->
        Keyword.fetch!(spec, :doc)
    end
  end
end
