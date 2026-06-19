defmodule Skia.Codegen.Rusty.StyleHelpers do
  @moduledoc false

  use RustQ.Meta

  alias RustQ.Type, as: R

  @spec generated_asts() :: [RustQ.Rust.AST.Function.t()]
  def generated_asts, do: __rustq_asts__()

  @spec decode_clip_op(R.atom()) :: R.nif_result(R.option(ClipOp.t()))
  defrust decode_clip_op(value) do
    {:ok, some(unwrap!(GeneratedEnums.decode_clip_op(value)))}
  end

  @spec apply_paint_effects(R.mut_ref(Paint.t()), R.slice({R.atom(), R.term()})) ::
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
