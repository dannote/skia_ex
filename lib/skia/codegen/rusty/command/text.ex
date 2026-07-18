defmodule Skia.Codegen.Rusty.Command.Text do
  @moduledoc """
  Rusty Elixir text drawing implementation generation.
  """

  alias Skia.Codegen.Command.Domain.Text

  use Skia.Codegen.Rusty.CommandDomain,
    from: Text,
    commands: [:text_blob, :text],
    helpers: [
      :draw_paragraph_text,
      :register_span_typefaces,
      :text_style_from_opts,
      :paragraph_paint_y,
      :decode_text_align,
      :decode_text_decoration,
      :decode_text_decoration_style,
      :decode_text_decoration_mode,
      :decode_text_direction
    ],
    rust_packages: [{"skia-safe", [manifest_path: "native/skia_native/Cargo.toml"]}]

  use Skia.Codegen.Rusty.Support.Args

  alias RustQ.Type, as: R

  @spec draw_text_blob_impl(
          R.ref(SkiaSafe.Canvas.t()),
          R.vec(term()),
          GeneratedOpts.TextBlobOpts.t(R.lifetime(:a)),
          R.slice({atom(), term()})
        ) :: R.nif_result(R.unit())
  defrust draw_text_blob_impl(canvas, args, opts, raw_opts) do
    blob = text_blob_from_term(first_arg_term!())

    paint =
      case opts.fill do
        {:some, term} -> decode_paint(term)
        :none -> fill_paint(Color.BLACK)
      end

    apply_paint_effects(paint, raw_opts)
    canvas.draw_text_blob(blob, {opts.x, opts.y}, paint)

    :ok
  end

  @spec draw_text_impl(
          R.ref(SkiaSafe.Canvas.t()),
          R.vec(term()),
          GeneratedOpts.TextOpts.t(R.lifetime(:a)),
          R.slice({atom(), term()})
        ) :: R.nif_result(R.unit())
  defrust draw_text_impl(canvas, args, opts, _raw_opts) do
    text = decode_as!(args.first().ok_or(badarg()), R.path(:String))
    size = opts.size.unwrap_or(16.0)

    font =
      case opts.font do
        {:some, term} -> font_from_term(term, size)
        :none -> Font.default()
      end

    font.set_size(size)

    paint =
      case opts.fill do
        {:some, term} -> fill_paint(decode_color(term))
        :none -> fill_paint(Color.BLACK)
      end

    case opts.width do
      {:some, width} ->
        draw_paragraph_text(canvas, text, opts.x, opts.y, width, size, paint, opts)

      :none ->
        canvas.draw_str(text, {opts.x, opts.y}, font, paint)
    end

    :ok
  end

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

    case opts.font do
      {:some, term} ->
        font = font_from_term(term, size)
        text_style.set_font_families([font.typeface().family_name()])
        text_style.set_typeface(font.typeface())

      :none ->
        :ok
    end

    case ref(opts.font_family) do
      {:some, family} -> text_style.set_font_families([family])
      :none -> :ok
    end

    case opts.line_height do
      {:some, line_height} ->
        text_style.set_height(line_height / size)
        text_style.set_height_override(true)

      :none ->
        :ok
    end

    case opts.letter_spacing do
      {:some, letter_spacing} -> text_style.set_letter_spacing(letter_spacing)
      :none -> :ok
    end

    case opts.decoration do
      {:some, decoration} -> text_style.set_decoration_type(decode_text_decoration(decoration))
      :none -> :ok
    end

    case opts.decoration_style do
      {:some, style} -> text_style.set_decoration_style(decode_text_decoration_style(style))
      :none -> :ok
    end

    case opts.decoration_mode do
      {:some, mode} -> text_style.set_decoration_mode(unwrap!(decode_text_decoration_mode(mode)))
      :none -> :ok
    end

    case opts.decoration_color do
      {:some, color} -> text_style.set_decoration_color(decode_color(color))
      :none -> :ok
    end

    paragraph_style = ParagraphStyle.new()
    paragraph_style.set_text_style(text_style)

    case opts.align do
      {:some, align} -> paragraph_style.set_text_align(decode_text_align(align))
      :none -> :ok
    end

    case opts.direction do
      {:some, direction} ->
        paragraph_style.set_text_direction(decode_text_direction(direction))

      :none ->
        :ok
    end

    case opts.max_lines do
      {:some, max_lines} -> paragraph_style.set_max_lines(max_lines)
      :none -> :ok
    end

    case ref(opts.ellipsis) do
      {:some, ellipsis} -> paragraph_style.set_ellipsis(ellipsis)
      :none -> :ok
    end

    font_collection = FontCollection.new()
    provider = TypefaceFontProvider.new()

    case opts.font do
      {:some, term} ->
        font = font_from_term(term, size)
        provider.register_typeface(font.typeface(), none())

      :none ->
        :ok
    end

    spans =
      case opts.spans do
        {:some, spans_term} ->
          some(decode_as!(spans_term, R.vec({R.path(:String), R.vec({atom(), term()})})))

        :none ->
          none()
      end

    case ref(spans) do
      {:some, values} -> register_span_typefaces(mut_ref(provider), values, size)
      :none -> :ok
    end

    font_collection.set_asset_font_manager(some(FontMgr.from(provider)))
    font_collection.set_default_font_manager(FontMgr.default(), none())
    paragraph_builder = ParagraphBuilder.new(paragraph_style, font_collection)

    case spans do
      {:some, values} ->
        for {span_text, style_opts} <- values do
          span_style = text_style_from_opts(text_style, ref(style_opts))
          paragraph_builder.push_style(span_style)
          paragraph_builder.add_text(span_text)
          paragraph_builder.pop()
        end

      :none ->
        paragraph_builder.push_style(text_style)
        paragraph_builder.add_text(text)
        paragraph_builder.pop()
    end

    paragraph = paragraph_builder.build()
    paragraph.layout(width)

    paint_y =
      case opts.height do
        {:some, height} ->
          case opts.vertical_align do
            {:some, align} -> unwrap!(paragraph_paint_y(y, height, paragraph.height(), align))
            :none -> y
          end

        :none ->
          y
      end

    case opts.height do
      {:some, height} ->
        canvas.save()
        canvas.clip_rect(Rect.from_xywh(x, y, width, height), ClipOp.Intersect, true)
        paragraph.paint(canvas, Point.new(x, paint_y))
        canvas.restore()

      :none ->
        paragraph.paint(canvas, Point.new(x, paint_y))
    end

    :ok
  end

  @spec register_span_typefaces(
          R.mut_ref(R.path(:TypefaceFontProvider)),
          R.slice({R.path(:String), R.vec({atom(), term()})}),
          R.f32()
        ) :: R.nif_result(R.unit())
  defrust register_span_typefaces(provider, spans, size) do
    for {_span_text, style_opts} <- spans do
      case opt_term(style_opts, Atoms.font()) do
        {:some, term} ->
          font = font_from_term(term, size)
          provider.register_typeface(font.typeface(), none())

        :none ->
          :ok
      end
    end

    :ok
  end

  @spec text_style_from_opts(R.ref(R.path(:TextStyle)), R.slice({atom(), term()})) ::
          R.nif_result(R.path(:TextStyle))
  defrust text_style_from_opts(base, opts) do
    style = base.clone()

    case opt_f32_option(opts, Atoms.size()) do
      {:some, size} -> style.set_font_size(size)
      :none -> :ok
    end

    case opt_term(opts, Atoms.fill()) do
      {:some, fill} -> style.set_color(decode_color(fill))
      :none -> :ok
    end

    case opt_term(opts, Atoms.font()) do
      {:some, term} ->
        font = font_from_term(term, base.font_size())
        style.set_font_families([font.typeface().family_name()])
        style.set_typeface(font.typeface())

      :none ->
        :ok
    end

    case opt_term(opts, Atoms.font_family()) do
      {:some, term} ->
        family = decode_as!(term, R.path(:String))
        style.set_font_families([family])

      :none ->
        :ok
    end

    case opt_f32_option(opts, Atoms.line_height()) do
      {:some, line_height} ->
        font_size = opt_f32_option(opts, Atoms.size()).unwrap_or(base.font_size())
        style.set_height(line_height / font_size)
        style.set_height_override(true)

      :none ->
        :ok
    end

    case opt_f32_option(opts, Atoms.letter_spacing()) do
      {:some, letter_spacing} -> style.set_letter_spacing(letter_spacing)
      :none -> :ok
    end

    case opt_term(opts, Atoms.decoration()) do
      {:some, term} ->
        decoration = decode_as!(term, atom())
        style.set_decoration_type(decode_text_decoration(decoration))

      :none ->
        :ok
    end

    case opt_term(opts, Atoms.decoration_style()) do
      {:some, term} ->
        decoration_style = decode_as!(term, atom())
        style.set_decoration_style(decode_text_decoration_style(decoration_style))

      :none ->
        :ok
    end

    case opt_term(opts, Atoms.decoration_mode()) do
      {:some, term} ->
        decoration_mode = decode_as!(term, atom())
        style.set_decoration_mode(unwrap!(decode_text_decoration_mode(decoration_mode)))

      :none ->
        :ok
    end

    case opt_term(opts, Atoms.decoration_color()) do
      {:some, color} -> style.set_decoration_color(decode_color(color))
      :none -> :ok
    end

    {:ok, style}
  end

  @spec paragraph_paint_y(R.f32(), R.f32(), R.f32(), atom()) :: R.nif_result(R.f32())
  defrust paragraph_paint_y(y, height, content_height, align) do
    remaining = (height - content_height).max(0.0)

    case align do
      :top -> {:ok, y}
      :center -> {:ok, y + remaining / 2.0}
      :bottom -> {:ok, y + remaining}
      _ -> {:error, badarg()}
    end
  end

  @spec decode_text_align(atom()) :: R.nif_result(R.path(:TextAlign))
  defrust decode_text_align(value) do
    case value do
      :center -> {:ok, TextAlign.Center}
      :right -> {:ok, TextAlign.Right}
      :justify -> {:ok, TextAlign.Justify}
      :left -> {:ok, TextAlign.Left}
      _ -> {:error, badarg()}
    end
  end

  @spec decode_text_decoration(atom()) :: R.nif_result(R.path(:TextDecoration))
  defrust decode_text_decoration(value) do
    case value do
      atom when atom == Atoms.none() -> {:ok, TextDecoration.NO_DECORATION}
      atom when atom == Atoms.underline() -> {:ok, TextDecoration.UNDERLINE}
      atom when atom == Atoms.line_through() -> {:ok, TextDecoration.LINE_THROUGH}
      _ -> {:error, badarg()}
    end
  end

  @spec decode_text_decoration_style(atom()) :: R.nif_result(R.path(:TextDecorationStyle))
  defrust decode_text_decoration_style(value) do
    case value do
      :solid -> {:ok, TextDecorationStyle.Solid}
      :double -> {:ok, TextDecorationStyle.Double}
      :dotted -> {:ok, TextDecorationStyle.Dotted}
      :dashed -> {:ok, TextDecorationStyle.Dashed}
      :wavy -> {:ok, TextDecorationStyle.Wavy}
      _ -> {:error, badarg()}
    end
  end

  @spec decode_text_decoration_mode(atom()) :: R.nif_result(R.path(:DecorationMode))
  defrust decode_text_decoration_mode(value) do
    case value do
      :gaps -> {:ok, DecorationMode.default()}
      :through -> {:ok, DecorationMode.Through}
      _ -> {:error, badarg()}
    end
  end

  @spec decode_text_direction(atom()) :: R.nif_result(R.path(:TextDirection))
  defrust decode_text_direction(value) do
    case value do
      :rtl -> {:ok, TextDirection.RTL}
      :ltr -> {:ok, TextDirection.LTR}
      _ -> {:error, badarg()}
    end
  end
end
