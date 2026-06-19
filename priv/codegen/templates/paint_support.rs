fn runtime_uniform_data(
    effect: &RuntimeEffect,
    float_uniforms: Vec<(String, Vec<f64>)>,
    int_uniforms: Vec<(String, Vec<i64>)>,
) -> NifResult<Data> {
    let mut bytes = vec![0_u8; effect.uniform_size()];

    for (name, values) in float_uniforms {
        let uniform = effect.find_uniform(&name).ok_or(rustler::Error::BadArg)?;
        let offset = uniform.offset();
        let byte_len = values.len() * std::mem::size_of::<f32>();
        if offset + byte_len > bytes.len() || byte_len > uniform.size_in_bytes() {
            return Err(rustler::Error::BadArg);
        }
        for (index, value) in values.into_iter().enumerate() {
            let start = offset + index * std::mem::size_of::<f32>();
            bytes[start..start + 4].copy_from_slice(&(value as f32).to_ne_bytes());
        }
    }

    for (name, values) in int_uniforms {
        let uniform = effect.find_uniform(&name).ok_or(rustler::Error::BadArg)?;
        let offset = uniform.offset();
        let byte_len = values.len() * std::mem::size_of::<i32>();
        if offset + byte_len > bytes.len() || byte_len > uniform.size_in_bytes() {
            return Err(rustler::Error::BadArg);
        }
        for (index, value) in values.into_iter().enumerate() {
            let start = offset + index * std::mem::size_of::<i32>();
            bytes[start..start + 4].copy_from_slice(&(value as i32).to_ne_bytes());
        }
    }

    Ok(Data::new_copy(&bytes))
}

fn runtime_children(effect: &RuntimeEffect, children: Vec<(String, Term)>) -> NifResult<Vec<ChildPtr>> {
    let effect_children = effect.children();
    let mut ordered: Vec<Option<ChildPtr>> = vec![None; effect_children.len()];

    for (name, child_term) in children {
        let child = effect.find_child(&name).ok_or(rustler::Error::BadArg)?;
        let paint = decode_paint(child_term)?;
        let shader = paint.shader().ok_or(rustler::Error::BadArg)?;
        ordered[child.index()] = Some(ChildPtr::from(shader));
    }

    ordered.into_iter().collect::<Option<Vec<_>>>().ok_or(rustler::Error::BadArg)
}

fn decode_paint(term: Term) -> NifResult<Paint> {
    if let Ok(color) = decode_color(term) {
        return Ok(fill_paint(color));
    }

    if let Ok((tag, from, to, stops, tile_mode, matrix_term)) =
        term.decode::<(Atom, (f64, f64), (f64, f64), Vec<Term>, Atom, Term)>()
    {
        if tag == atoms::linear_gradient() {
            let (colors, positions) = decode_gradient_stops(stops)?;
            let tile_mode = generated_enums::decode_tile_mode(tile_mode)?;
            let matrix = optional_matrix_from_term(matrix_term)?;
            let mut paint = Paint::default();
            paint.set_anti_alias(true).set_style(PaintStyle::Fill);
            if let Some(shader) = Shader::linear_gradient(
                ((from.0 as f32, from.1 as f32), (to.0 as f32, to.1 as f32)),
                colors.as_slice(),
                positions.as_deref(),
                tile_mode,
                None,
                matrix.as_ref(),
            ) {
                paint.set_shader(shader);
            }
            return Ok(paint);
        }
    }

    if let Ok((tag, start, start_radius, end, end_radius, gradient_opts)) =
        term.decode::<(Atom, (f64, f64), f64, (f64, f64), f64, Term)>()
    {
        if tag == atoms::two_point_conical_gradient() {
            let (stops, tile_mode, matrix_term) = gradient_opts.decode::<(Vec<Term>, Atom, Term)>()?;
            let (colors, positions) = decode_gradient_stops(stops)?;
            let tile_mode = generated_enums::decode_tile_mode(tile_mode)?;
            let matrix = optional_matrix_from_term(matrix_term)?;
            let mut paint = Paint::default();
            paint.set_anti_alias(true).set_style(PaintStyle::Fill);
            if let Some(shader) = Shader::two_point_conical_gradient(
                (start.0 as f32, start.1 as f32),
                start_radius as f32,
                (end.0 as f32, end.1 as f32),
                end_radius as f32,
                colors.as_slice(),
                positions.as_deref(),
                tile_mode,
                None,
                matrix.as_ref(),
            ) {
                paint.set_shader(shader);
            }
            return Ok(paint);
        }
    }

    if let Ok((tag, color_term)) = term.decode::<(Atom, Term)>() {
        if tag == atoms::color_shader() {
            let mut paint = Paint::default();
            paint.set_anti_alias(true).set_style(PaintStyle::Fill);
            paint.set_shader(skia_safe::shaders::color(decode_color(color_term)?));
            return Ok(paint);
        }
    }

    if let Ok((tag, center, radius, stops, tile_mode, matrix_term)) =
        term.decode::<(Atom, (f64, f64), f64, Vec<Term>, Atom, Term)>()
    {
        if tag == atoms::radial_gradient() {
            let (colors, positions) = decode_gradient_stops(stops)?;
            let tile_mode = generated_enums::decode_tile_mode(tile_mode)?;
            let matrix = optional_matrix_from_term(matrix_term)?;
            let mut paint = Paint::default();
            paint.set_anti_alias(true).set_style(PaintStyle::Fill);
            if let Some(shader) = Shader::radial_gradient(
                (center.0 as f32, center.1 as f32),
                radius as f32,
                colors.as_slice(),
                positions.as_deref(),
                tile_mode,
                None,
                matrix.as_ref(),
            ) {
                paint.set_shader(shader);
            }
            return Ok(paint);
        }
    }

    if let Ok((tag, center, start_degrees, end_degrees, stops, tile_mode, matrix_term)) =
        term.decode::<(Atom, (f64, f64), f64, f64, Vec<Term>, Atom, Term)>()
    {
        if tag == atoms::sweep_gradient() {
            let (colors, positions) = decode_gradient_stops(stops)?;
            let tile_mode = generated_enums::decode_tile_mode(tile_mode)?;
            let matrix = optional_matrix_from_term(matrix_term)?;
            let mut paint = Paint::default();
            paint.set_anti_alias(true).set_style(PaintStyle::Fill);
            if let Some(shader) = Shader::sweep_gradient(
                (center.0 as f32, center.1 as f32),
                colors.as_slice(),
                positions.as_deref(),
                tile_mode,
                Some((start_degrees as f32, end_degrees as f32)),
                None,
                matrix.as_ref(),
            ) {
                paint.set_shader(shader);
            }
            return Ok(paint);
        }
    }

    if let Ok((tag, effect_term, float_uniforms, int_uniforms, children, matrix_term)) =
        term.decode::<(Atom, Term, Vec<(String, Vec<f64>)>, Vec<(String, Vec<i64>)>, Vec<(String, Term)>, Term)>()
    {
        if tag == atoms::runtime_effect_shader() {
            let effect = runtime_effect_from_term(effect_term)?;
            let uniforms = runtime_uniform_data(&effect, float_uniforms, int_uniforms)?;
            let children = runtime_children(&effect, children)?;
            let matrix = optional_matrix_from_term(matrix_term)?;
            let mut paint = Paint::default();
            paint.set_anti_alias(true).set_style(PaintStyle::Fill);
            paint.set_shader(effect.make_shader(uniforms, children.as_slice(), matrix.as_ref()).ok_or(rustler::Error::BadArg)?);
            return Ok(paint);
        }
    }

    if let Ok((tag, image_term, tile_x, tile_y, sampling_term, matrix_term)) =
        term.decode::<(Atom, Term, Atom, Atom, Term, Term)>()
    {
        if tag == atoms::image_shader() {
            let image = image_from_term(image_term)?;
            let tile_x = generated_enums::decode_tile_mode(tile_x)?;
            let tile_y = generated_enums::decode_tile_mode(tile_y)?;
            let sampling = decode_sampling_options(sampling_term)?;
            let matrix = optional_matrix_from_term(matrix_term)?;
            let mut paint = Paint::default();
            paint.set_anti_alias(true).set_style(PaintStyle::Fill);
            if let Some(shader) = image.to_shader((tile_x, tile_y), sampling, matrix.as_ref()) {
                paint.set_shader(shader);
            }
            return Ok(paint);
        }
    }

    if let Ok((tag, picture_term, tile_x, tile_y, filter_mode, matrix_term, tile_rect_term)) =
        term.decode::<(Atom, Term, Atom, Atom, Atom, Term, Term)>()
    {
        if tag == atoms::picture_shader() {
            let picture = picture_from_term(picture_term)?;
            let tile_x = generated_enums::decode_tile_mode(tile_x)?;
            let tile_y = generated_enums::decode_tile_mode(tile_y)?;
            let filter_mode = generated_enums::decode_sampling(filter_mode)?;
            let matrix = optional_matrix_from_term(matrix_term)?;
            let tile_rect = optional_rect_from_term(tile_rect_term)?;
            let mut paint = Paint::default();
            paint.set_anti_alias(true).set_style(PaintStyle::Fill);
            paint.set_shader(picture.to_shader((tile_x, tile_y), filter_mode, matrix.as_ref(), tile_rect.as_ref()));
            return Ok(paint);
        }
    }

    Err(rustler::Error::BadArg)
}

fn decode_color_filter(term: Term) -> NifResult<ColorFilter> {
    if let Ok((tag, color_term, blend_mode)) = term.decode::<(Atom, Term, Atom)>() {
        if tag == atoms::blend_color_filter() {
            return color_filters::blend(
                decode_color(color_term)?,
                generated_enums::decode_blend_mode(blend_mode)?,
            )
            .ok_or(rustler::Error::BadArg);
        }
    }

    if let Ok((tag, matrix, clamp)) = term.decode::<(Atom, Vec<f64>, bool)>() {
        if tag == atoms::matrix_color_filter() && matrix.len() == 20 {
            let mut values = [0.0_f32; 20];
            for (index, value) in matrix.into_iter().enumerate() {
                values[index] = value as f32;
            }
            let clamp = if clamp { color_filters::Clamp::Yes } else { color_filters::Clamp::No };
            return Ok(color_filters::matrix_row_major(&values, clamp));
        }
    }

    if let Ok((tag, outer, inner)) = term.decode::<(Atom, Term, Term)>() {
        if tag == atoms::compose_color_filter() {
            return color_filters::compose(decode_color_filter(outer)?, decode_color_filter(inner)?)
                .ok_or(rustler::Error::BadArg);
        }
    }

    Err(rustler::Error::BadArg)
}







