defmodule Skia.Codegen.Rusty.Text do
  @moduledoc """
  Rusty Elixir text drawing implementation generation.
  """

  alias Skia.Codegen.Commands.Text

  use Skia.Codegen.Rusty.Domain,
    from: Text,
    commands: [:text_blob, :text],
    helpers: [
      :draw_paragraph_text,
      :text_style_from_opts,
      :decode_text_align,
      :decode_text_direction
    ],
    rust_packages: [{"skia-safe", [manifest_path: "native/skia_native/Cargo.toml"]}]

  use Skia.Codegen.Rusty.Args

  alias RustQ.Type, as: R

  @spec draw_text_blob_impl(
          R.ref(SkiaSafe.Canvas.t()),
          R.vec(term()),
          GeneratedOpts.TextBlobOpts.t(R.lifetime(:a)),
          R.slice({atom(), term()})
        ) :: R.nif_result(R.unit())
  defrust draw_text_blob_impl(canvas, args, opts, raw_opts) do
    blob = unwrap!(text_blob_from_term(first_arg_term!()))

    paint =
      case opts.fill do
        {:some, term} -> unwrap!(decode_paint(term))
        :none -> fill_paint(Color.BLACK)
      end

    unwrap!(apply_paint_effects(paint, raw_opts))
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
    text = decode_as!(unwrap!(args.first().ok_or(badarg())), R.path(:String))
    size = opts.size.unwrap_or(16.0)

    font =
      case opts.font do
        {:some, term} -> unwrap!(font_from_term(term, size))
        :none -> Font.default()
      end

    font.set_size(size)

    paint =
      case opts.fill do
        {:some, term} -> fill_paint(unwrap!(decode_color(term)))
        :none -> fill_paint(Color.BLACK)
      end

    case opts.width do
      {:some, width} ->
        unwrap!(
          draw_paragraph_text(
            canvas,
            ref(text),
            opts.x,
            opts.y,
            width,
            size,
            paint,
            opts
          )
        )

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
    paragraph_style.set_text_style(text_style)

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
    paragraph_builder = ParagraphBuilder.new(paragraph_style, font_collection)

    case opts.spans do
      {:some, spans_term} ->
        spans = decode_as!(spans_term, R.vec({R.path(:String), R.vec({atom(), term()})}))

        for {span_text, style_opts} <- spans do
          span_style = unwrap!(text_style_from_opts(text_style, ref(style_opts)))
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
    paragraph.paint(canvas, Point.new(x, y))
    :ok
  end

  @spec text_style_from_opts(R.ref(R.path(:TextStyle)), R.slice({atom(), term()})) ::
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

  @spec decode_text_direction(atom()) :: R.nif_result(R.path(:TextDirection))
  defrust decode_text_direction(value) do
    case value do
      :rtl -> {:ok, TextDirection.RTL}
      :ltr -> {:ok, TextDirection.LTR}
      _ -> {:error, badarg()}
    end
  end
end
