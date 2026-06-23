defmodule Skia.Codegen.RustyTest do
  use ExUnit.Case, async: true

  test "generated save/restore handlers come from direct Rusty layer bodies" do
    layers = Skia.Codegen.generated_layers()

    assert layers =~
             "fn draw_save<'a>(canvas: &skia_safe::Canvas, _command: Term<'a>) -> NifResult<()>"

    assert layers =~ "canvas.save();"
    refute layers =~ "draw_save_impl"

    assert layers =~
             "fn draw_restore<'a>(canvas: &skia_safe::Canvas, _command: Term<'a>) -> NifResult<()>"

    assert layers =~ "canvas.restore();"
    refute layers =~ "draw_restore_impl"
  end

  test "layer impls are generated from Rusty Elixir" do
    source = Skia.Codegen.generated_layers()

    assert source =~ "fn draw_save_layer_impl<'a>("

    assert source =~
             "let alpha = (opts.opacity.unwrap_or(1.0).clamp(0.0, 1.0) * 255.0).round() as u8;"

    assert source =~ "canvas.save_layer(&rec);"
  end

  test "generated Rusty command handlers decode command plumbing in domain modules" do
    source = Skia.Codegen.generated_draw_paths()

    assert source =~ "fn draw_path<'a>("
    assert source =~ "let args = decode_args(command)?;"
    assert source =~ "generated_opts::decode_path_opts(&opts)?"
    assert source =~ "draw_path_impl(canvas, args, decoded_opts, &opts)"
  end

  test "text impls are generated from Rusty Elixir" do
    source = Skia.Codegen.generated_text()

    assert source =~ "fn draw_text_blob_impl<'a>("

    assert source =~
             "let blob = text_blob_from_term(*args.first().ok_or(rustler::Error::BadArg)?)?;"

    assert source =~ "apply_paint_effects(&mut paint, raw_opts)?;"

    assert source =~ "fn draw_text_impl<'a>("
    assert source =~ "let text = args.first().ok_or(rustler::Error::BadArg)?.decode::<String>()?;"

    assert source =~ "draw_paragraph_text("
    assert source =~ "&text"
    assert source =~ "&paint"
    assert source =~ "&opts"
  end

  test "transform impls are generated from Rusty Elixir" do
    source = Skia.Codegen.generated_transforms()

    assert source =~ "fn draw_translate_impl<'a>("
    assert source =~ "opts: generated_opts::TranslateOpts<'a>"
    assert source =~ "canvas.translate((opts.x, opts.y));"

    assert source =~ "fn draw_scale_impl<'a>("
    assert source =~ "canvas.scale((opts.x, opts.y));"

    assert source =~ "fn draw_rotate_impl<'a>("
    assert source =~ "canvas.rotate(opts.degrees, None);"

    assert source =~ "fn draw_rotate_at_impl<'a>("
    assert source =~ "canvas.rotate(opts.degrees, Some(Point::new(opts.x, opts.y)));"

    assert source =~ "fn draw_concat_impl<'a>("
    assert source =~ "let matrix = matrix_from_term(opts.matrix)?;"
    assert source =~ "canvas.concat(&matrix);"
  end

  test "clip impls are generated from Rusty Elixir" do
    source = Skia.Codegen.generated_clips()

    assert source =~ "fn clip_rect_impl<'a>("
    assert source =~ "let rect = Rect::from_xywh(opts.x, opts.y, opts.width, opts.height);"
    assert source =~ "canvas.clip_rect(rect, clip_op, antialias);"

    assert source =~ "fn clip_circle_impl<'a>("
    assert source =~ "let mut builder = PathBuilder::new();"
    assert source =~ "builder.add_circle(Point::new(opts.x, opts.y), opts.radius, None);"

    assert source =~ "fn clip_path_impl<'a>("
    assert source =~ "let mut path = build_path(*args.first().ok_or(rustler::Error::BadArg)?)?;"
    assert source =~ "apply_fill_rule(&mut path, raw_opts)?;"
  end

  test "image impls are generated from Rusty Elixir" do
    source = Skia.Codegen.generated_images()

    assert source =~ "fn draw_image_impl<'a>("
    assert source =~ "let image = image_from_term(*args.first().ok_or(rustler::Error::BadArg)?)?;"
    assert source =~ "let alpha = (opacity.clamp(0.0, 1.0) * 255.0).round() as u8;"

    assert source =~
             "draw_image_source_or_default(canvas, image, source, opts, sampling, &paint);"

    assert source =~ "fn draw_picture_impl<'a>("
    assert source =~ "canvas.draw_picture(&picture, None, Some(&paint));"
  end

  test "style helpers infer propagation from narrow skia-safe source metadata" do
    source = Skia.Codegen.generated_style_helpers()

    assert source =~ "paint.set_blend_mode(generated_enums::decode_blend_mode(atom)?);"
    assert source =~ "paint.set_stroke_cap(generated_enums::decode_stroke_cap(atom)?);"
    assert source =~ "paint.set_stroke_join(generated_enums::decode_stroke_join(atom)?);"
    assert source =~ "path.set_fill_type(generated_enums::decode_fill_rule(atom)?);"
    assert source =~ "apply_paint_effects(paint, opts)?;"
  end

  test "path impls are generated from Rusty Elixir" do
    source = Skia.Codegen.generated_draw_paths()

    assert source =~ "fn draw_path_impl<'a>("
    assert source =~ "let mut path = build_path(*args.first().ok_or(rustler::Error::BadArg)?)?;"
    assert source =~ "apply_fill_rule(&mut path, raw_opts)?;"

    assert source =~ "fn draw_path_op_impl<'a>("
    assert source =~ "let op = generated_enums::decode_path_op(opts.path_op)?;"
    assert source =~ "let mut path = a.op(&b, op).ok_or(rustler::Error::BadArg)?;"

    assert source =~ "fn draw_path_outline_impl<'a>("
    assert source =~ "path_utils::fill_path_with_paint(&path, &stroke, &mut builder, None, None)"
    assert source =~ "canvas.draw_path(&outline, &paint);"
  end

  test "shape impls are generated from Rusty Elixir" do
    source = Skia.Codegen.generated_shapes()

    assert source =~ "fn draw_clear_impl<'a>("
    assert source =~ "canvas.clear(color);"

    assert source =~ "fn draw_circle_impl<'a>("
    assert source =~ "opts: generated_opts::CircleOpts<'a>"
    assert source =~ "let center = Point::new(opts.x, opts.y);"
    assert source =~ "opt_fill_paint(raw_opts, atoms::fill())?"
    assert source =~ "opt_color(raw_opts, atoms::stroke())?"
    assert source =~ "canvas.draw_circle(center, opts.radius, &paint);"

    assert source =~ "fn draw_oval_impl<'a>("
    assert source =~ "opts: generated_opts::OvalOpts<'a>"
    assert source =~ "let rect = Rect::from_xywh(opts.x, opts.y, opts.width, opts.height);"
    assert source =~ "canvas.draw_oval(rect, &paint);"

    assert source =~ "fn draw_line_impl<'a>("
    assert source =~ "opts: generated_opts::LineOpts<'a>"
    assert source =~ "let color = decode_color(opts.stroke)?;"

    assert source =~
             "canvas.draw_line(point_from_term(opts.from)?, point_from_term(opts.to)?, &paint);"
  end
end
