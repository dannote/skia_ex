fn draw_image_impl<'a>(
    surface: &mut skia_safe::Surface,
    args: Vec<Term<'a>>,
    image_opts: generated_opts::ImageOpts<'a>,
    opts: &[(Atom, Term<'a>)],
) -> NifResult<()> {
    let image = image_from_term(*args.first().ok_or(rustler::Error::BadArg)?)?;
    let mut paint = Paint::default();
    paint.set_anti_alias(true);

    if let Some(opacity) = image_opts.opacity {
        paint.set_alpha((opacity.clamp(0.0, 1.0) * 255.0).round() as u8);
    }
    apply_blend_mode(&mut paint, &opts)?;

    let sampling = opt_sampling(&opts, atoms::sampling())?;
    let source = match image_opts.source {
        Some(term) => Some(rect_from_term(term)?),
        None => None,
    };

    match (image_opts.width, image_opts.height, source) {
        (Some(width), Some(height), source) => {
            let src = source
                .as_ref()
                .map(|rect| (rect, skia_safe::canvas::SrcRectConstraint::Strict));
            surface.canvas().draw_image_rect_with_sampling_options(
                image,
                src,
                Rect::from_xywh(image_opts.x, image_opts.y, width, height),
                sampling,
                &paint,
            );
        }
        (_, _, Some(source)) => {
            surface.canvas().draw_image_rect_with_sampling_options(
                image,
                Some((&source, skia_safe::canvas::SrcRectConstraint::Strict)),
                Rect::from_xywh(image_opts.x, image_opts.y, source.width(), source.height()),
                sampling,
                &paint,
            );
        }
        _ => {
            surface.canvas().draw_image_with_sampling_options(
                image,
                (image_opts.x, image_opts.y),
                sampling,
                Some(&paint),
            );
        }
    }

    Ok(())
}
