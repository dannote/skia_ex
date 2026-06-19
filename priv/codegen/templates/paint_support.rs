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


