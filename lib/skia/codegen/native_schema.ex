defmodule Skia.Codegen.NativeSchema do
  @moduledoc """
  Structural introspection for original `skia-safe` Rust APIs.

  This module is the intended replacement direction for command declarations:
  read native Rust items through `RustQ.Syn`, then let Skia add a small ergonomic
  overlay for Elixir naming/defaults.

  The only Skia-specific source lookup here is the native crate manifest path.
  Cargo package/source discovery is delegated to `RustQ.Cargo`; impl/method
  discovery is delegated to `RustQ.Syn.Index`. This module does not parse Rust
  source with regex.
  """

  @native_manifest "native/skia_native/Cargo.toml"

  @type method :: RustQ.Syn.Method.t()

  @spec index() :: RustQ.Syn.Index.t()
  def index do
    :persistent_term.get({__MODULE__, :index}, nil) || build_index()
  end

  @spec methods(String.t()) :: [method()]
  def methods(target) when is_binary(target) do
    target
    |> normalize_target()
    |> then(&RustQ.Syn.Index.methods(index(), &1))
  end

  @spec method!(String.t(), String.t()) :: method()
  def method!(target, name) when is_binary(target) and is_binary(name) do
    RustQ.Syn.Index.method!(index(), normalize_target(target), name)
  rescue
    RuntimeError -> raise "cannot find skia_safe::#{target}::#{name}"
  end

  @spec source_root!() :: Path.t()
  def source_root! do
    RustQ.Cargo.package_source!("skia-safe", manifest_path: @native_manifest)
  end

  @spec source_paths() :: [Path.t()]
  def source_paths do
    source_root!()
    |> Path.join("**/*.rs")
    |> Path.wildcard()
    |> Enum.sort()
  end

  defp build_index do
    index = RustQ.Syn.Index.from_paths(source_paths())
    :persistent_term.put({__MODULE__, :index}, index)
    index
  end

  defp normalize_target("path_utils"), do: "path_utils"
  defp normalize_target("pathops"), do: "pathops"
  defp normalize_target(target), do: target
end
