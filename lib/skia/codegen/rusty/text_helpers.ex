defmodule Skia.Codegen.Rusty.TextHelpers do
  @moduledoc false

  use RustQ.Meta

  alias RustQ.Type, as: R

  @spec generated_asts() :: [RustQ.Rust.AST.Function.t()]
  def generated_asts, do: __rustq_asts__()

  @spec text_style_from_opts(R.ref(R.path(:TextStyle)), R.slice({R.atom(), R.term()})) ::
          R.nif_result(R.path(:TextStyle))
  defrust text_style_from_opts(base, opts) do
    style = base.clone()

    case unwrap!(opt_f32_option(opts, Atoms.size())) do
      {:some, size} -> style.set_font_size(size)
      :none -> :ok
    end

    case opt_term(opts, Atoms.fill()) do
      {:some, fill} -> style.set_color(unwrap!(decode_color(fill)))
      :none -> :ok
    end

    case opt_term(opts, Atoms.font_family()) do
      {:some, term} ->
        family = decode_as!(term, R.path(:String))
        style.set_font_families(ref([ref(family)]))

      :none ->
        :ok
    end

    case unwrap!(opt_f32_option(opts, Atoms.line_height())) do
      {:some, line_height} ->
        font_size = unwrap!(opt_f32_option(opts, Atoms.size())).unwrap_or(base.font_size())
        style.set_height(line_height / font_size)
        style.set_height_override(true)

      :none ->
        :ok
    end

    {:ok, style}
  end

  @spec decode_text_align(R.atom()) :: R.nif_result(R.path(:TextAlign))
  defrust decode_text_align(value) do
    case value do
      :center -> {:ok, TextAlign.Center}
      :right -> {:ok, TextAlign.Right}
      :justify -> {:ok, TextAlign.Justify}
      :left -> {:ok, TextAlign.Left}
      _ -> {:error, badarg()}
    end
  end

  @spec decode_text_direction(R.atom()) :: R.nif_result(R.path(:TextDirection))
  defrust decode_text_direction(value) do
    case value do
      :rtl -> {:ok, TextDirection.RTL}
      :ltr -> {:ok, TextDirection.LTR}
      _ -> {:error, badarg()}
    end
  end
end
