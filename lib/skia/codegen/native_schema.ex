defmodule Skia.Codegen.NativeSchema do
  @moduledoc """
  Structural introspection for original `skia-safe` Rust APIs.

  This module is the intended replacement direction for command declarations:
  read native Rust items through `RustQ.Syn`, then let Skia add a small ergonomic
  overlay for Elixir naming/defaults. It does not parse Rust source with regex.
  """

  @safe_src "skia-safe-*/src"

  @source_files %{
    "Canvas" => "core/canvas.rs",
    "Font" => "core/font.rs",
    "ImageFilter" => "effects/image_filters.rs",
    "Path" => "pathops.rs",
    "path_utils" => "core/path_utils.rs",
    "pathops" => "pathops.rs"
  }

  @type method :: RustQ.Syn.Method.t()

  @spec methods(String.t()) :: [method()]
  def methods(target) when is_binary(target) do
    target
    |> source_path!()
    |> RustQ.Syn.parse_file!()
    |> RustQ.Syn.impls()
    |> Enum.filter(&impl_target?(&1, target))
    |> Enum.flat_map(& &1.methods)
  end

  @spec method!(String.t(), String.t()) :: method()
  def method!(target, name) when is_binary(target) and is_binary(name) do
    methods(target)
    |> Enum.find(&(&1.name == name))
    |> case do
      nil -> raise "cannot find skia_safe::#{target}::#{name}"
      method -> method
    end
  end

  @spec source_path!(String.t()) :: Path.t()
  def source_path!(target) do
    target
    |> source_relative_path!()
    |> skia_safe_source_path!()
  end

  defp impl_target?(%RustQ.Syn.Impl{target: impl_target}, target) do
    impl_target == target or String.starts_with?(impl_target, "#{target} <")
  end

  defp source_relative_path!(target) do
    Map.fetch!(@source_files, target)
  rescue
    KeyError -> raise "unknown skia-safe source target #{inspect(target)}"
  end

  defp skia_safe_source_path!(relative_path) do
    [System.user_home!(), ".cargo/registry/src/*", @safe_src, relative_path]
    |> Path.join()
    |> Path.wildcard()
    |> Enum.sort(:desc)
    |> List.first()
    |> case do
      nil -> raise "cannot find skia-safe source #{relative_path}"
      path -> path
    end
  end
end
