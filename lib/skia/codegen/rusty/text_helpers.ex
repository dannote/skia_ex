defmodule Skia.Codegen.Rusty.TextHelpers do
  @moduledoc false

  use RustQ.Meta

  alias RustQ.Type, as: R

  @spec generated_asts() :: [RustQ.Rust.AST.Function.t()]
  def generated_asts, do: __rustq_asts__()

  @spec draw_paragraph_text(
          R.ref(R.path({:skia_safe, :Canvas})),
          R.str(),
          R.f32(),
          R.f32(),
          R.f32(),
          R.f32(),
          R.ref(Paint.t()),
          R.ref(GeneratedOpts.TextOpts.t(R.lifetime(:a)))
        ) :: R.nif_result(R.unit())
  defrust draw_paragraph_text(canvas, text, x, y, width, size, paint, opts) do
    text_style = TextStyle.new()
    text_style.set_font_size(size)
    text_style.set_color(paint.color())

    case ref(opts.font_family) do
      {:some, family} -> text_style.set_font_families(ref([family]))
      :none -> :ok
    end

    case opts.line_height do
      {:some, line_height} ->
        text_style.set_height(line_height / size)
        text_style.set_height_override(true)

      :none ->
        :ok
    end

    paragraph_style = ParagraphStyle.new()
    paragraph_style.set_text_style(ref(text_style))

    case opts.align do
      {:some, align} -> paragraph_style.set_text_align(unwrap!(decode_text_align(align)))
      :none -> :ok
    end

    case opts.direction do
      {:some, direction} ->
        paragraph_style.set_text_direction(unwrap!(decode_text_direction(direction)))

      :none ->
        :ok
    end

    font_collection = FontCollection.new()
    font_collection.set_default_font_manager(FontMgr.default(), none())
    paragraph_builder = ParagraphBuilder.new(ref(paragraph_style), font_collection)

    case opts.spans do
      {:some, spans_term} ->
        spans = decode_as!(spans_term, R.vec({R.path(:String), R.vec({R.atom(), R.term()})}))

        for {span_text, style_opts} <- spans do
          span_style = unwrap!(text_style_from_opts(ref(text_style), ref(style_opts)))
          paragraph_builder.push_style(ref(span_style))
          paragraph_builder.add_text(span_text)
          paragraph_builder.pop()
        end

      :none ->
        paragraph_builder.push_style(ref(text_style))
        paragraph_builder.add_text(text)
        paragraph_builder.pop()
    end

    paragraph = paragraph_builder.build()
    paragraph.layout(width)
    paragraph.paint(canvas, Point.new(x, y))
    :ok
  end

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
