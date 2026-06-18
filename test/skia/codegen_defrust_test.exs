defmodule Skia.CodegenDefrustTest do
  use ExUnit.Case, async: true

  test "generated save/restore command macros expose handlers and impls" do
    source = Skia.Codegen.GeneratedCommands.__rustq_source__()

    assert source =~ "fn draw_save<'a>(canvas: &Canvas, _command: Term<'a>) -> NifResult<()>"
    assert source =~ "draw_save_impl(canvas)"
    assert source =~ "fn draw_save_impl(canvas: &Canvas) -> NifResult<()>"
    assert source =~ "canvas.save();"

    assert source =~ "fn draw_restore<'a>(canvas: &Canvas, _command: Term<'a>) -> NifResult<()>"
    assert source =~ "draw_restore_impl(canvas)"
    assert source =~ "fn draw_restore_impl(canvas: &Canvas) -> NifResult<()>"
    assert source =~ "canvas.restore();"
  end

  test "generated layer impl module remains empty while legacy layer bodies stay in codegen" do
    assert Skia.Codegen.GeneratedLayers.__rustq_asts__() == []
  end

  test "generated handlers decode command plumbing through direct Rust paths" do
    source = Skia.Codegen.GeneratedHandlers.__rustq_source__()

    refute source =~ "fn draw_save("
    refute source =~ "fn draw_restore("
    assert source =~ "fn draw_path<'a>("
    assert source =~ "command.map_get(atoms::args())?"
    assert source =~ "generated_opts::decode_path_opts(&opts)?"
    assert source =~ "draw_path_impl(canvas, args, decoded_opts, &opts)"
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
