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

fn decode_image_filter(term: Term) -> NifResult<skia_safe::ImageFilter> {
    if let Ok((tag, sigma_x, sigma_y, tile_mode)) = term.decode::<(Atom, f64, f64, Atom)>() {
        if tag == atoms::blur_filter() {
            let tile_mode = generated_enums::decode_tile_mode(tile_mode)?;
            return image_filters::blur((sigma_x as f32, sigma_y as f32), tile_mode, None, None)
                .ok_or(rustler::Error::BadArg);
        }
    }

    if let Ok((tag, outer, inner)) = term.decode::<(Atom, Term, Term)>() {
        if tag == atoms::compose_filter() {
            return image_filters::compose(decode_image_filter(outer)?, decode_image_filter(inner)?)
                .ok_or(rustler::Error::BadArg);
        }
    }

    if let Ok((tag, x, y, input_term)) = term.decode::<(Atom, f64, f64, Term)>() {
        if tag == atoms::offset_filter() {
            return image_filters::offset(
                (x as f32, y as f32),
                optional_image_filter_from_term(input_term)?,
                None,
            )
            .ok_or(rustler::Error::BadArg);
        }
    }

    if let Ok((tag, dx, dy, sigma_x, sigma_y, color_term, shadow_opts)) =
        term.decode::<(Atom, f64, f64, f64, f64, Term, Term)>()
    {
        if tag == atoms::drop_shadow_filter() {
            let (input_term, shadow_only) = shadow_opts.decode::<(Term, bool)>()?;
            let color = decode_color(color_term)?;
            let input = optional_image_filter_from_term(input_term)?;
            let filter = if shadow_only {
                image_filters::drop_shadow_only(
                    (dx as f32, dy as f32),
                    (sigma_x as f32, sigma_y as f32),
                    color,
                    None,
                    input,
                    None,
                )
            } else {
                image_filters::drop_shadow(
                    (dx as f32, dy as f32),
                    (sigma_x as f32, sigma_y as f32),
                    color,
                    None,
                    input,
                    None,
                )
            };
            return filter.ok_or(rustler::Error::BadArg);
        }
    }

    if let Ok((tag, filter_term, input_term)) = term.decode::<(Atom, Term, Term)>() {
        if tag == atoms::color_filter_image_filter() {
            return image_filters::color_filter(
                decode_color_filter(filter_term)?,
                optional_image_filter_from_term(input_term)?,
                None,
            )
            .ok_or(rustler::Error::BadArg);
        }
    }

    if let Ok((tag, shader_term)) = term.decode::<(Atom, Term)>() {
        if tag == atoms::shader_image_filter() {
            return image_filters::shader(decode_shader(shader_term)?, None)
                .ok_or(rustler::Error::BadArg);
        }
    }

    if let Ok((tag, bounds, zoom, inset, sampling_term, input_term)) =
        term.decode::<(Atom, (f64, f64, f64, f64), f64, f64, Term, Term)>()
    {
        if tag == atoms::magnifier_filter() {
            return image_filters::magnifier(
                Rect::from_xywh(bounds.0 as f32, bounds.1 as f32, bounds.2 as f32, bounds.3 as f32),
                zoom as f32,
                inset as f32,
                decode_sampling_options(sampling_term)?,
                optional_image_filter_from_term(input_term)?,
                None,
            )
            .ok_or(rustler::Error::BadArg);
        }
    }

    if let Ok((tag, kernel_size, kernel, conv_opts)) =
        term.decode::<(Atom, (i64, i64), Vec<f64>, Term)>()
    {
        if tag == atoms::matrix_convolution_filter() {
            let (gain, bias, offset, tile, convolve_alpha, input_term) =
                conv_opts.decode::<(f64, f64, (i64, i64), Atom, bool, Term)>()?;
            let kernel = kernel.into_iter().map(|value| value as f32).collect::<Vec<_>>();
            return image_filters::matrix_convolution(
                (kernel_size.0 as i32, kernel_size.1 as i32),
                kernel.as_slice(),
                gain as f32,
                bias as f32,
                (offset.0 as i32, offset.1 as i32),
                generated_enums::decode_tile_mode(tile)?,
                convolve_alpha,
                optional_image_filter_from_term(input_term)?,
                None,
            )
            .ok_or(rustler::Error::BadArg);
        }
    }

    if let Ok((tag, matrix_term, sampling_term, input_term)) = term.decode::<(Atom, Term, Term, Term)>() {
        if tag == atoms::matrix_transform_filter() {
            return image_filters::matrix_transform(
                &matrix_from_term(matrix_term)?,
                decode_sampling_options(sampling_term)?,
                optional_image_filter_from_term(input_term)?,
            )
            .ok_or(rustler::Error::BadArg);
        }
    }

    if let Ok((tag, filters)) = term.decode::<(Atom, Vec<Term>)>() {
        if tag == atoms::merge_filter() {
            let filters = filters
                .into_iter()
                .map(optional_image_filter_from_term)
                .collect::<NifResult<Vec<_>>>()?;
            return image_filters::merge(filters, None).ok_or(rustler::Error::BadArg);
        }
    }

    if let Ok((tag, src, dst, input_term)) =
        term.decode::<(Atom, (f64, f64, f64, f64), (f64, f64, f64, f64), Term)>()
    {
        if tag == atoms::tile_filter() {
            return image_filters::tile(
                Rect::from_xywh(src.0 as f32, src.1 as f32, src.2 as f32, src.3 as f32),
                Rect::from_xywh(dst.0 as f32, dst.1 as f32, dst.2 as f32, dst.3 as f32),
                optional_image_filter_from_term(input_term)?,
            )
            .ok_or(rustler::Error::BadArg);
        }
    }

    if let Ok((tag, op, radius_x, radius_y, input_term)) =
        term.decode::<(Atom, Atom, f64, f64, Term)>()
    {
        if tag == atoms::morphology_filter() {
            let input = optional_image_filter_from_term(input_term)?;
            let filter = if op == atoms::dilate() {
                image_filters::dilate((radius_x as f32, radius_y as f32), input, None)
            } else if op == atoms::erode() {
                image_filters::erode((radius_x as f32, radius_y as f32), input, None)
            } else {
                return Err(rustler::Error::BadArg);
            };
            return filter.ok_or(rustler::Error::BadArg);
        }
    }

    Err(rustler::Error::BadArg)
}

fn optional_image_filter_from_term(term: Term) -> NifResult<Option<skia_safe::ImageFilter>> {
    if term.decode::<Atom>().is_ok_and(|atom| atom == atoms::nil()) {
        Ok(None)
    } else {
        Ok(Some(decode_image_filter(term)?))
    }
}

fn decode_shader(term: Term) -> NifResult<Shader> {
    let paint = decode_paint(term)?;
    paint.shader().ok_or(rustler::Error::BadArg)
}

fn decode_mask_filter(term: Term) -> NifResult<MaskFilter> {
    if let Ok((tag, style, sigma, respect_ctm)) = term.decode::<(Atom, Atom, f64, bool)>() {
        if tag == atoms::blur_mask_filter() {
            return MaskFilter::blur(generated_enums::decode_blur_style(style)?, sigma as f32, respect_ctm)
                .ok_or(rustler::Error::BadArg);
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

fn decode_path_effect(term: Term) -> NifResult<PathEffect> {
    if let Ok((tag, intervals, phase)) = term.decode::<(Atom, Vec<f64>, f64)>() {
        if tag == atoms::dash_path_effect() {
            let intervals = intervals.into_iter().map(|value| value as f32).collect::<Vec<_>>();
            return PathEffect::dash(intervals.as_slice(), phase as f32)
                .ok_or(rustler::Error::BadArg);
        }
    }

    if let Ok((tag, radius)) = term.decode::<(Atom, f64)>() {
        if tag == atoms::corner_path_effect() {
            return PathEffect::corner_path(radius as f32).ok_or(rustler::Error::BadArg);
        }
    }

    if let Ok((tag, start, stop, mode)) = term.decode::<(Atom, f64, f64, Atom)>() {
        if tag == atoms::trim_path_effect() {
            let mode = if mode == atoms::inverted() {
                skia_safe::trim_path_effect::Mode::Inverted
            } else if mode == atoms::normal() {
                skia_safe::trim_path_effect::Mode::Normal
            } else {
                return Err(rustler::Error::BadArg);
            };
            return PathEffect::trim(start as f32, stop as f32, mode)
                .ok_or(rustler::Error::BadArg);
        }
    }

    if let Ok((tag, segment_length, deviation, seed_term)) =
        term.decode::<(Atom, f64, f64, Term)>()
    {
        if tag == atoms::discrete_path_effect() {
            let seed = if seed_term.decode::<Atom>().is_ok_and(|atom| atom == atoms::nil()) {
                None
            } else {
                Some(seed_term.decode::<i64>()? as u32)
            };
            return PathEffect::discrete(segment_length as f32, deviation as f32, seed)
                .ok_or(rustler::Error::BadArg);
        }
    }

    if let Ok((tag, path_term, advance, phase, style)) = term.decode::<(Atom, Term, f64, f64, Atom)>() {
        if tag == atoms::path_1d_effect() {
            let style = decode_path_1d_style(style)?;
            return PathEffect::path_1d(&build_path(path_term)?, advance as f32, phase as f32, style)
                .ok_or(rustler::Error::BadArg);
        }
    }

    if let Ok((tag, width, matrix_term)) = term.decode::<(Atom, f64, Term)>() {
        if tag == atoms::line_2d_effect() {
            return PathEffect::line_2d(width as f32, &matrix_from_term(matrix_term)?)
                .ok_or(rustler::Error::BadArg);
        }
    }

    if let Ok((tag, matrix_term, path_term)) = term.decode::<(Atom, Term, Term)>() {
        if tag == atoms::path_2d_effect() {
            return Ok(PathEffect::path_2d(&matrix_from_term(matrix_term)?, &build_path(path_term)?));
        }
    }

    if let Ok((tag, first, second)) = term.decode::<(Atom, Term, Term)>() {
        if tag == atoms::compose_path_effect() {
            return Ok(PathEffect::compose(decode_path_effect(first)?, decode_path_effect(second)?));
        }
        if tag == atoms::sum_path_effect() {
            return Ok(PathEffect::sum(decode_path_effect(first)?, decode_path_effect(second)?));
        }
    }

    Err(rustler::Error::BadArg)
}


fn decode_sampling_options(term: Term) -> NifResult<SamplingOptions> {
    if let Ok((tag, filter, mipmap)) = term.decode::<(Atom, Atom, Atom)>() {
        if tag == atoms::sampling_options() {
            return Ok(SamplingOptions::new(
                generated_enums::decode_sampling(filter)?,
                generated_enums::decode_mipmap_mode(mipmap)?,
            ));
        }
    }

    if let Ok((tag, cubic_term)) = term.decode::<(Atom, Term)>() {
        if tag == atoms::sampling_cubic() {
            let cubic = if cubic_term.decode::<Atom>().is_ok_and(|atom| atom == atoms::mitchell()) {
                CubicResampler::mitchell()
            } else if cubic_term.decode::<Atom>().is_ok_and(|atom| atom == atoms::catmull_rom()) {
                CubicResampler::catmull_rom()
            } else {
                let (b, c) = cubic_term.decode::<(f64, f64)>()?;
                CubicResampler { b: b as f32, c: c as f32 }
            };
            return Ok(SamplingOptions::from(cubic));
        }

        if tag == atoms::sampling_aniso() {
            return Ok(SamplingOptions::from_aniso(cubic_term.decode::<i64>()? as i32));
        }
    }

    Err(rustler::Error::BadArg)
}




