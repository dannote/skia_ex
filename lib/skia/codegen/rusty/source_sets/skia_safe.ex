defmodule Skia.Codegen.Rusty.SourceSets.SkiaSafe do
  @moduledoc """
  Imports narrow callable metadata from selected `skia-safe` source files.

  This keeps RustQ's callable metadata source structural and upstream-backed
  without indexing the entire `skia-safe` crate for modules that only need a
  small set of method signatures.
  """

  @source_files %{
    color: ["core/color.rs"],
    color_filter: ["core/color_filter.rs"],
    data: ["core/data.rs"],
    gradient_shader: ["effects/gradient_shader.rs"],
    image: ["core/image.rs"],
    image_filters: ["effects/image_filters.rs"],
    mask_filter: ["core/mask_filter.rs"],
    picture: ["core/picture.rs"],
    paint: ["core.rs", "core/paint.rs"],
    path: ["core/path.rs"],
    path_effects: [
      "core/path_effect.rs",
      "effects/_1d_path_effect.rs",
      "effects/_2d_path_effect.rs"
    ],
    runtime_effect: ["effects/runtime_effect.rs"],
    sampling_options: ["core/sampling_options.rs"],
    shader: ["core/shader.rs"]
  }

  defmacro __using__(opts) do
    rust_sources =
      opts |> Keyword.get(:rust_sources, []) |> expand_value!(__CALLER__) |> List.wrap()

    callable_modules =
      opts |> Keyword.get(:callable_modules, []) |> expand_value!(__CALLER__) |> List.wrap()

    files =
      opts
      |> Keyword.get(:files, Map.keys(@source_files))
      |> expand_value!(__CALLER__)
      |> List.wrap()

    manifest_path =
      opts
      |> Keyword.get(:manifest_path, "native/skia_native/Cargo.toml")
      |> expand_value!(__CALLER__)

    skia_safe_sources = skia_safe_sources!(files, manifest_path)

    quote do
      use RustQ.Meta,
        rust_sources: unquote(Macro.escape(rust_sources ++ skia_safe_sources)),
        callable_modules: unquote(Macro.escape(callable_modules))
    end
  end

  defp expand_value!(quoted, _env) when is_binary(quoted), do: quoted

  defp expand_value!(quoted, env) do
    {value, _binding} = Code.eval_quoted(quoted, [], env)
    value
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
