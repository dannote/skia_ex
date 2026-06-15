fn draw_clear_impl<'a>(surface: &mut skia_safe::Surface, args: Vec<Term<'a>>) -> NifResult<()> {
    if let Some(color) = args.first().and_then(|term| decode_color(*term).ok()) {
        surface.canvas().clear(color);
    }

    Ok(())
}

fn draw_rect_impl<'a>(
    surface: &mut skia_safe::Surface,
    rect_opts: generated_opts::RectOpts<'a>,
    opts: &[(Atom, Term<'a>)],
) -> NifResult<()> {
    let rect = Rect::from_xywh(rect_opts.x, rect_opts.y, rect_opts.width, rect_opts.height);
    draw_rect_shape(surface, rect, rect_opts.radius.unwrap_or(0.0), &opts)
}

fn draw_oval_impl<'a>(
    surface: &mut skia_safe::Surface,
    oval_opts: generated_opts::OvalOpts<'a>,
    opts: &[(Atom, Term<'a>)],
) -> NifResult<()> {
    let rect = Rect::from_xywh(oval_opts.x, oval_opts.y, oval_opts.width, oval_opts.height);

    if let Some(mut paint) = opt_fill_paint(opts, atoms::fill())? {
        apply_blend_mode(&mut paint, opts)?;
        surface.canvas().draw_oval(rect, &paint);
    }

    if let Some(color) = opt_color(opts, atoms::stroke())? {
        let paint = stroke_paint(color, oval_opts.stroke_width.unwrap_or(1.0), opts)?;
        surface.canvas().draw_oval(rect, &paint);
    }

    Ok(())
}

fn draw_arc_impl<'a>(
    surface: &mut skia_safe::Surface,
    arc_opts: generated_opts::ArcOpts<'a>,
    opts: &[(Atom, Term<'a>)],
) -> NifResult<()> {
    let rect = Rect::from_xywh(arc_opts.x, arc_opts.y, arc_opts.width, arc_opts.height);
    let use_center = arc_opts.use_center.unwrap_or(false);

    if let Some(mut paint) = opt_fill_paint(opts, atoms::fill())? {
        apply_blend_mode(&mut paint, opts)?;
        surface.canvas().draw_arc(
            rect,
            arc_opts.start_degrees,
            arc_opts.sweep_degrees,
            use_center,
            &paint,
        );
    }

    if let Some(color) = opt_color(opts, atoms::stroke())? {
        let paint = stroke_paint(color, arc_opts.stroke_width.unwrap_or(1.0), opts)?;
        surface.canvas().draw_arc(
            rect,
            arc_opts.start_degrees,
            arc_opts.sweep_degrees,
            use_center,
            &paint,
        );
    }

    Ok(())
}

fn draw_circle_impl<'a>(
    surface: &mut skia_safe::Surface,
    circle_opts: generated_opts::CircleOpts<'a>,
    opts: &[(Atom, Term<'a>)],
) -> NifResult<()> {
    let center = Point::new(circle_opts.x, circle_opts.y);

    if let Some(paint) = opt_fill_paint(&opts, atoms::fill())? {
        surface
            .canvas()
            .draw_circle(center, circle_opts.radius, &paint);
    }

    if let Some(color) = opt_color(&opts, atoms::stroke())? {
        let paint = stroke_paint(color, circle_opts.stroke_width.unwrap_or(1.0), &opts)?;
        surface
            .canvas()
            .draw_circle(center, circle_opts.radius, &paint);
    }

    Ok(())
}

fn draw_line_impl<'a>(
    surface: &mut skia_safe::Surface,
    line_opts: generated_opts::LineOpts<'a>,
    opts: &[(Atom, Term<'a>)],
) -> NifResult<()> {
    let color = decode_color(line_opts.stroke)?;
    let paint = stroke_paint(color, line_opts.stroke_width.unwrap_or(1.0), &opts)?;

    surface.canvas().draw_line(
        point_from_term(line_opts.from)?,
        point_from_term(line_opts.to)?,
        &paint,
    );
    Ok(())
}

fn draw_rect_shape(
    surface: &mut skia_safe::Surface,
    rect: Rect,
    radius: f32,
    opts: &[(Atom, Term)],
) -> NifResult<()> {
    if let Some(mut paint) = opt_fill_paint(opts, atoms::fill())? {
        apply_blend_mode(&mut paint, opts)?;
        if radius > 0.0 {
            surface
                .canvas()
                .draw_rrect(RRect::new_rect_xy(rect, radius, radius), &paint);
        } else {
            surface.canvas().draw_rect(rect, &paint);
        }
    }

    if let Some(color) = opt_color(opts, atoms::stroke())? {
        let paint = stroke_paint(
            color,
            opt_f32_default(opts, atoms::stroke_width(), 1.0)?,
            opts,
        )?;

        if radius > 0.0 {
            surface
                .canvas()
                .draw_rrect(RRect::new_rect_xy(rect, radius, radius), &paint);
        } else {
            surface.canvas().draw_rect(rect, &paint);
        }
    }

    Ok(())
}
