fn apply_stroke_options<'a>(paint: &mut Paint, opts: &[(Atom, Term<'a>)]) -> NifResult<()> {
    __rq_options!();
    if let Some(miter) = opt_f32_option(opts, atoms::stroke_miter())? {
        paint.set_stroke_miter(miter);
    }
    Ok(())
}
