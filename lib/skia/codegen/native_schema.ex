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

  defmodule Method do
    @moduledoc "Native skia-safe method descriptor."
    defstruct [:target, :name, :method]

    @type t :: %__MODULE__{
            target: String.t(),
            name: String.t(),
            method: RustQ.Syn.Method.t()
          }
  end

  @type method :: RustQ.Syn.Method.t()
  @type expected_arg ::
          :self_ref
          | {:ref, String.t()}
          | {:impl_trait, String.t(), [String.t()]}
          | {:path, String.t()}
          | :any
  @type expected_return :: {:ref, String.t()} | {:path, String.t()} | :none | :any

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

  @spec descriptor!(String.t(), String.t()) :: Method.t()
  def descriptor!(target, name) when is_binary(target) and is_binary(name) do
    %Method{target: target, name: name, method: method!(target, name)}
  end

  @spec assert_method_shape!(String.t(), String.t(), keyword()) :: Method.t()
  def assert_method_shape!(target, name, opts) do
    descriptor = descriptor!(target, name)
    method = descriptor.method

    expected_args = Keyword.get(opts, :args, :any)
    expected_returns = Keyword.get(opts, :returns, :any)

    if expected_args != :any do
      actual = Enum.map(method.args, & &1.type_ast)

      unless length(actual) == length(expected_args) and
               Enum.zip(actual, expected_args)
               |> Enum.all?(fn {type, expected} -> type_matches?(type, expected) end) do
        raise "unexpected native args for #{target}::#{name}: #{inspect(method.args)}"
      end
    end

    unless return_matches?(method.returns_ast, expected_returns) do
      raise "unexpected native return for #{target}::#{name}: #{inspect(method.returns_ast)}"
    end

    descriptor
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

  defp type_matches?(_type, :any), do: true
  defp type_matches?(%RustQ.Syn.Type.Ref{inner: %RustQ.Syn.Type.Self{}}, :self_ref), do: true
  defp type_matches?(%RustQ.Syn.Type.Ref{inner: %RustQ.Syn.Type.Self{}}, {:ref, "Self"}), do: true
  defp type_matches?(type, {:ref, name}), do: RustQ.Syn.Type.ref_to?(type, name)

  defp type_matches?(type, {:impl_trait, trait, args}),
    do: RustQ.Syn.Type.impl_trait?(type, trait, args)

  defp type_matches?(type, {:path, name}), do: RustQ.Syn.Type.path?(type, name)
  defp type_matches?(_type, _expected), do: false

  defp return_matches?(_type, :any), do: true
  defp return_matches?(nil, :none), do: true
  defp return_matches?(type, {:ref, name}), do: type_matches?(type, {:ref, name})
  defp return_matches?(type, {:path, name}), do: type_matches?(type, {:path, name})
  defp return_matches?(_type, _expected), do: false

  defp normalize_target("path_utils"), do: "path_utils"
  defp normalize_target("pathops"), do: "pathops"
  defp normalize_target(target), do: target
end
