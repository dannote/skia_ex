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

  @spec descriptor!(RustQ.NativeRef.t()) :: RustQ.NativeDescriptor.t()
  def descriptor!(%RustQ.NativeRef{} = ref) do
    RustQ.NativeDescriptor.resolve!(index(), ref)
  end

  @spec descriptor!(String.t(), String.t()) :: RustQ.NativeDescriptor.t()
  def descriptor!(target, name) when is_binary(target) and is_binary(name) do
    descriptor!(RustQ.NativeRef.new(target, name, package: "skia-safe"))
  end

  @spec assert_method_shape!(String.t(), String.t(), keyword()) :: RustQ.NativeDescriptor.t()
  def assert_method_shape!(target, name, opts) do
    target
    |> descriptor!(name)
    |> RustQ.NativeDescriptor.assert_shape!(opts)
  end

  @spec package!() :: RustQ.Cargo.Package.t()
  def package!, do: index().package

  @spec source_root!() :: Path.t()
  def source_root!, do: package!().manifest_path |> Path.dirname()

  @spec source_paths() :: [Path.t()]
  def source_paths do
    source_root!()
    |> Path.join("**/*.rs")
    |> Path.wildcard()
    |> Enum.sort()
  end

  defp build_index do
    index = RustQ.Syn.Index.from_package("skia-safe", manifest_path: @native_manifest)
    :persistent_term.put({__MODULE__, :index}, index)
    index
  end

  defp normalize_target("path_utils"), do: "path_utils"
  defp normalize_target("pathops"), do: "pathops"
  defp normalize_target(target), do: target
end
