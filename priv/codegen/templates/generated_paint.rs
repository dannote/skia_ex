fn decode_paint(term: Term) -> NifResult<Paint> {
    if let Ok(color) = decode_color(term) {
        return Ok(fill_paint(color));
    }

    if let Ok((tag, from, to, stops, matrix_term)) =
        term.decode::<(Atom, (f64, f64), (f64, f64), Vec<Term>, Term)>()
    {
        if tag == atoms::linear_gradient() {
            let (colors, positions) = decode_gradient_stops(stops)?;
            let matrix = optional_matrix_from_term(matrix_term)?;
            let mut paint = Paint::default();
            paint.set_anti_alias(true).set_style(PaintStyle::Fill);
            if let Some(shader) = Shader::linear_gradient(
                ((from.0 as f32, from.1 as f32), (to.0 as f32, to.1 as f32)),
                colors.as_slice(),
                positions.as_deref(),
                TileMode::Clamp,
                None,
                matrix.as_ref(),
            ) {
                paint.set_shader(shader);
            }
            return Ok(paint);
        }
    }

    if let Ok((tag, center, radius, stops, matrix_term)) =
        term.decode::<(Atom, (f64, f64), f64, Vec<Term>, Term)>()
    {
        if tag == atoms::radial_gradient() {
            let (colors, positions) = decode_gradient_stops(stops)?;
            let matrix = optional_matrix_from_term(matrix_term)?;
            let mut paint = Paint::default();
            paint.set_anti_alias(true).set_style(PaintStyle::Fill);
            if let Some(shader) = Shader::radial_gradient(
                (center.0 as f32, center.1 as f32),
                radius as f32,
                colors.as_slice(),
                positions.as_deref(),
                TileMode::Clamp,
                None,
                matrix.as_ref(),
            ) {
                paint.set_shader(shader);
            }
            return Ok(paint);
        }
    }

    if let Ok((tag, center, start_degrees, end_degrees, stops, matrix_term)) =
        term.decode::<(Atom, (f64, f64), f64, f64, Vec<Term>, Term)>()
    {
        if tag == atoms::sweep_gradient() {
            let (colors, positions) = decode_gradient_stops(stops)?;
            let matrix = optional_matrix_from_term(matrix_term)?;
            let mut paint = Paint::default();
            paint.set_anti_alias(true).set_style(PaintStyle::Fill);
            if let Some(shader) = Shader::sweep_gradient(
                (center.0 as f32, center.1 as f32),
                colors.as_slice(),
                positions.as_deref(),
                TileMode::Clamp,
                Some((start_degrees as f32, end_degrees as f32)),
                None,
                matrix.as_ref(),
            ) {
                paint.set_shader(shader);
            }
            return Ok(paint);
        }
    }

    if let Ok((tag, image_term, tile_x, tile_y, sampling, matrix_term)) =
        term.decode::<(Atom, Term, Atom, Atom, Atom, Term)>()
    {
        if tag == atoms::image_shader() {
            let image = image_from_term(image_term)?;
            let tile_x = generated_enums::decode_tile_mode(tile_x)?;
            let tile_y = generated_enums::decode_tile_mode(tile_y)?;
            let sampling = SamplingOptions::from(generated_enums::decode_sampling(sampling)?);
            let matrix = optional_matrix_from_term(matrix_term)?;
            let mut paint = Paint::default();
            paint.set_anti_alias(true).set_style(PaintStyle::Fill);
            if let Some(shader) = image.to_shader((tile_x, tile_y), sampling, matrix.as_ref()) {
                paint.set_shader(shader);
            }
            return Ok(paint);
        }
    }

    Err(rustler::Error::BadArg)
}

fn optional_matrix_from_term(matrix_term: Term) -> NifResult<Option<Matrix>> {
    if matrix_term.decode::<Atom>().is_ok_and(|atom| atom == atoms::nil()) {
        Ok(None)
    } else {
        Ok(Some(matrix_from_term(matrix_term)?))
    }
}

fn decode_gradient_stops(stops: Vec<Term>) -> NifResult<(Vec<Color>, Option<Vec<f32>>)> {
    let mut colors = Vec::with_capacity(stops.len());
    let mut positions = Vec::with_capacity(stops.len());
    let mut explicit_positions = true;

    for stop in stops {
        if let Ok((tag, color_term, position)) = stop.decode::<(Atom, Term, f64)>() {
            if tag == atoms::gradient_stop() {
                colors.push(decode_color(color_term)?);
                positions.push(position as f32);
                continue;
            }
        }

        explicit_positions = false;
        colors.push(decode_color(stop)?);
    }

    Ok((colors, if explicit_positions { Some(positions) } else { None }))
}

fn decode_color(term: Term) -> NifResult<Color> {
    let (tag, red, green, blue, alpha) = term.decode::<(Atom, u8, u8, u8, u8)>()?;

    if tag == atoms::rgba() {
        Ok(Color::from_argb(alpha, red, green, blue))
    } else {
        Err(rustler::Error::BadArg)
    }
}
