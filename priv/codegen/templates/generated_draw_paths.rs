fn draw_path_impl<'a>(
    surface: &mut skia_safe::Surface,
    args: Vec<Term<'a>>,
    path_opts: generated_opts::PathOpts<'a>,
    opts: &[(Atom, Term<'a>)],
) -> NifResult<()> {
    let mut path = build_path(*args.first().ok_or(rustler::Error::BadArg)?)?;
    apply_fill_rule(&mut path, &opts)?;

    if let Some(fill) = path_opts.fill {
        let mut paint = decode_paint(fill)?;
        apply_blend_mode(&mut paint, &opts)?;
        surface.canvas().draw_path(&path, &paint);
    }

    if let Some(stroke) = path_opts.stroke {
        surface.canvas().draw_path(
            &path,
            &stroke_paint(
                decode_color(stroke)?,
                path_opts.stroke_width.unwrap_or(1.0),
                &opts,
            )?,
        );
    }

    Ok(())
}

fn draw_path_op_impl<'a>(
    surface: &mut skia_safe::Surface,
    args: Vec<Term<'a>>,
    path_opts: generated_opts::PathOpOpts<'a>,
    opts: &[(Atom, Term<'a>)],
) -> NifResult<()> {
    let a = build_path(*args.first().ok_or(rustler::Error::BadArg)?)?;
    let b = build_path(*args.get(1).ok_or(rustler::Error::BadArg)?)?;
    let op = generated_enums::decode_path_op(path_opts.path_op)?;
    let mut path = a.op(&b, op).ok_or(rustler::Error::BadArg)?;
    apply_fill_rule(&mut path, opts)?;

    if let Some(fill) = path_opts.fill {
        let mut paint = decode_paint(fill)?;
        apply_blend_mode(&mut paint, opts)?;
        surface.canvas().draw_path(&path, &paint);
    }

    if let Some(stroke) = path_opts.stroke {
        surface.canvas().draw_path(
            &path,
            &stroke_paint(
                decode_color(stroke)?,
                path_opts.stroke_width.unwrap_or(1.0),
                opts,
            )?,
        );
    }

    Ok(())
}
