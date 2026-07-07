defmodule Skia.Codegen.Rusty.Support.StyleHelpers do
  @moduledoc false

  use Skia.Codegen.Rusty.SourceSets.SkiaSafe,
    files: [:paint, :path],
    rust_sources: ["native/skia_native/src/generated_enums.rs"]

  alias RustQ.Type, as: R

  @spec opt_f32_option(R.slice({atom(), term()}), atom()) :: R.nif_result(R.option(R.f32()))
  def opt_f32_option(_opts, _key), do: raise("RustQ metadata only")

  @spec apply_blend_mode(R.mut_ref(Paint.t()), R.slice({atom(), term()})) ::
          R.nif_result(R.unit())
  defrust apply_blend_mode(paint, opts) do
    case opt_term(opts, Atoms.blend_mode()) do
      {:some, term} ->
        atom = decode_as!(term, R.atom())
        paint.set_blend_mode(GeneratedEnums.decode_blend_mode(atom))

      :none ->
        :ok
    end

    apply_paint_effects(paint, opts)
    :ok
  end

  @spec apply_stroke_options(R.mut_ref(Paint.t()), R.slice({atom(), term()})) ::
          R.nif_result(R.unit())
  defrust apply_stroke_options(paint, opts) do
    case opt_term(opts, Atoms.stroke_cap()) do
      {:some, term} ->
        atom = decode_as!(term, R.atom())
        paint.set_stroke_cap(GeneratedEnums.decode_stroke_cap(atom))

      :none ->
        :ok
    end

    case opt_term(opts, Atoms.stroke_join()) do
      {:some, term} ->
        atom = decode_as!(term, R.atom())
        paint.set_stroke_join(GeneratedEnums.decode_stroke_join(atom))

      :none ->
        :ok
    end

    case opt_f32_option(opts, Atoms.stroke_miter()) do
      {:some, miter} -> paint.set_stroke_miter(miter)
      :none -> :ok
    end

    :ok
  end

  @spec apply_fill_rule(R.mut_ref(SkiaSafe.Path.t()), R.slice({atom(), term()})) ::
          R.nif_result(R.unit())
  defrust apply_fill_rule(path, opts) do
    case opt_term(opts, Atoms.fill_rule()) do
      {:some, term} ->
        atom = decode_as!(term, R.atom())
        path.set_fill_type(GeneratedEnums.decode_fill_rule(atom))

      :none ->
        :ok
    end

    :ok
  end

  @spec decode_clip_op(atom()) :: R.nif_result(R.option(ClipOp.t()))
  defrust decode_clip_op(value) do
    {:ok, some(GeneratedEnums.decode_clip_op(value))}
  end

  @spec apply_paint_effects(R.mut_ref(Paint.t()), R.slice({atom(), term()})) ::
          R.nif_result(R.unit())
  defrust apply_paint_effects(paint, opts) do
    case opt_term(opts, Atoms.image_filter()) do
      {:some, term} -> paint.set_image_filter(unwrap!(decode_image_filter(term)))
      :none -> :ok
    end

    case opt_term(opts, Atoms.path_effect()) do
      {:some, term} -> paint.set_path_effect(unwrap!(decode_path_effect(term)))
      :none -> :ok
    end

    case opt_term(opts, Atoms.color_filter()) do
      {:some, term} -> paint.set_color_filter(unwrap!(decode_color_filter(term)))
      :none -> :ok
    end

    case opt_term(opts, Atoms.mask_filter()) do
      {:some, term} -> paint.set_mask_filter(unwrap!(decode_mask_filter(term)))
      :none -> :ok
    end

    :ok
  end
end
