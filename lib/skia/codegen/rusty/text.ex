defmodule Skia.Codegen.Rusty.Text do
  @moduledoc """
  Rusty Elixir text drawing implementation generation.

  Paragraph/text-style helper functions remain in `Skia.Codegen` until their
  builder-heavy internals are worth modeling structurally.
  """

  alias RustQ.Rust.AST
  alias Skia.Codegen.Commands.Text

  @commands [:text_blob, :text]

  @spec commands() :: [atom()]
  def commands, do: @commands

  @spec generated_asts() :: [AST.Function.t()]
  def generated_asts do
    Text.commands()
    |> Keyword.take(@commands)
    |> Enum.map(fn {_name, spec} -> spec |> Keyword.fetch!(:handler) |> impl_ast!() end)
  end

  defp impl_ast!(handler) do
    name = String.to_atom("#{handler}_impl")

    Enum.find(__rustq_asts__(), &(&1.name == name)) ||
      raise "missing Rusty text impl #{name}"
  end

  use RustQ.Meta
  use Skia.Codegen.Rusty.Args

  alias RustQ.Type, as: R

  @spec draw_text_blob_impl(
          R.ref(SkiaSafe.Canvas.t()),
          R.vec(R.term()),
          GeneratedOpts.TextBlobOpts.t(R.lifetime(:a)),
          R.slice({R.atom(), R.term()})
        ) :: R.nif_result(R.unit())
  defrust draw_text_blob_impl(canvas, args, opts, raw_opts) do
    blob = unwrap!(text_blob_from_term(first_arg_term!()))

    paint =
      case opts.fill do
        {:some, term} -> unwrap!(decode_paint(term))
        :none -> fill_paint(Color.BLACK)
      end

    unwrap!(apply_paint_effects(mut_ref(paint), raw_opts))
    canvas.draw_text_blob(ref(blob), {opts.x, opts.y}, ref(paint))

    :ok
  end

  @spec draw_text_impl(
          R.ref(SkiaSafe.Canvas.t()),
          R.vec(R.term()),
          GeneratedOpts.TextOpts.t(R.lifetime(:a)),
          R.slice({R.atom(), R.term()})
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
            ref(paint),
            ref(opts)
          )
        )

      :none ->
        canvas.draw_str(text, {opts.x, opts.y}, ref(font), ref(paint))
    end

    :ok
  end
end
