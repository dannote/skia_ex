defmodule Skia.Codegen.Rusty.SkiaSafeSources do
  @moduledoc """
  Imports narrow callable metadata from selected `skia-safe` source files.

  This keeps RustQ's callable metadata source structural and upstream-backed
  without indexing the entire `skia-safe` crate for modules that only need a
  small set of method signatures.
  """

  @source_files %{
    gradient_shader: ["effects/gradient_shader.rs"],
    image: ["core/image.rs"],
    image_filters: ["effects/image_filters.rs"],
    picture: ["core/picture.rs"],
    paint: ["core.rs", "core/paint.rs"],
    path: ["core/path.rs"],
    runtime_effect: ["effects/runtime_effect.rs"]
  }

  defmacro __using__(opts) do
    rust_sources = Keyword.get(opts, :rust_sources, []) |> List.wrap()
    files = Keyword.get(opts, :files, Map.keys(@source_files)) |> List.wrap()
    manifest_path = Keyword.get(opts, :manifest_path, "native/skia_native/Cargo.toml")

    skia_safe_sources = skia_safe_sources!(files, manifest_path)

    quote do
      use RustQ.Meta, rust_sources: unquote(Macro.escape(rust_sources ++ skia_safe_sources))
    end
  end

  defp skia_safe_sources!(files, manifest_path) do
    source_root =
      "skia-safe"
      |> RustQ.Cargo.package_source!(manifest_path: manifest_path)
      |> Path.join("src")

    files
    |> Enum.flat_map(&Map.fetch!(@source_files, &1))
    |> Enum.uniq()
    |> Enum.map(&Path.join(source_root, &1))
  end
end
