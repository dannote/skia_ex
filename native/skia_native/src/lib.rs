#![allow(deprecated)]

use rustler::{Atom, Binary, Encoder, Env, NifResult, OwnedBinary, Resource, ResourceArc, Term};
use skia_safe::{
    paint, surfaces, AlphaType, BlendMode, Color, ColorType, Data, EncodedImageFormat, FilterMode,
    Font, FontMgr, FontStyle, IPoint, Image, ImageInfo, Paint, PaintStyle, PathBuilder,
    PathFillType, Point, RRect, Rect, SamplingOptions, Shader, TileMode,
};

struct EncodedImage {
    bytes: Vec<u8>,
}

#[rustler::resource_impl]
impl Resource for EncodedImage {}

struct EncodedFont {
    bytes: Vec<u8>,
}

#[rustler::resource_impl]
impl Resource for EncodedFont {}

mod atoms {
    include!("generated_atoms.rs");
}

mod generated_enums;
mod generated_opts;

#[rustler::nif(schedule = "DirtyCpu")]
fn render_png<'a>(env: Env<'a>, batch: Term<'a>) -> NifResult<Term<'a>> {
    encode_rendered(env, batch, EncodedImageFormat::PNG, 100)
}

#[rustler::nif(schedule = "DirtyCpu")]
fn render_jpeg<'a>(env: Env<'a>, batch: Term<'a>, quality: u32) -> NifResult<Term<'a>> {
    encode_rendered(env, batch, EncodedImageFormat::JPEG, quality)
}

#[rustler::nif(schedule = "DirtyCpu")]
fn render_webp<'a>(env: Env<'a>, batch: Term<'a>, quality: u32) -> NifResult<Term<'a>> {
    encode_rendered(env, batch, EncodedImageFormat::WEBP, quality)
}

#[rustler::nif(schedule = "DirtyCpu")]
fn render_rgba<'a>(env: Env<'a>, batch: Term<'a>) -> NifResult<Term<'a>> {
    let width = batch.map_get(atoms::width())?.decode::<i32>()?;
    let height = batch.map_get(atoms::height())?.decode::<i32>()?;
    let mut surface = match render_surface(batch)? {
        Ok(surface) => surface,
        Err(reason) => return Ok((atoms::error(), reason).encode(env)),
    };

    let stride = width as usize * 4;
    let mut pixels = vec![0_u8; stride * height as usize];
    let image_info = ImageInfo::new(
        (width, height),
        ColorType::RGBA8888,
        AlphaType::Premul,
        None,
    );

    if !surface.read_pixels(&image_info, &mut pixels, stride, IPoint::new(0, 0)) {
        return Ok((atoms::error(), atoms::render_failed()).encode(env));
    }

    Ok((
        atoms::ok(),
        (width, height, stride as i64, binary(env, &pixels)?),
    )
        .encode(env))
}

#[rustler::nif(schedule = "DirtyCpu")]
fn decode_image<'a>(env: Env<'a>, bytes: Binary<'a>) -> NifResult<Term<'a>> {
    let data = Data::new_copy(bytes.as_slice());
    let image = match Image::from_encoded(data) {
        Some(image) => image,
        None => return Ok((atoms::error(), atoms::invalid_image()).encode(env)),
    };

    let resource = ResourceArc::new(EncodedImage {
        bytes: bytes.as_slice().to_vec(),
    });

    Ok((atoms::ok(), resource, image.width(), image.height()).encode(env))
}

#[rustler::nif(schedule = "DirtyCpu")]
fn encode_image<'a>(
    env: Env<'a>,
    image_term: Term<'a>,
    format: Atom,
    quality: u32,
) -> NifResult<Term<'a>> {
    let image = image_from_term(image_term)?;
    let format = if format == Atom::from_bytes(env, b"png")? {
        EncodedImageFormat::PNG
    } else if format == Atom::from_bytes(env, b"jpeg")? {
        EncodedImageFormat::JPEG
    } else if format == Atom::from_bytes(env, b"webp")? {
        EncodedImageFormat::WEBP
    } else {
        return Ok((atoms::error(), atoms::unsupported_format()).encode(env));
    };

    match image.encode(None, format, quality.clamp(0, 100)) {
        Some(data) => Ok((atoms::ok(), binary(env, data.as_bytes())?).encode(env)),
        None => Ok((atoms::error(), atoms::unsupported_format()).encode(env)),
    }
}

#[rustler::nif(schedule = "DirtyCpu")]
fn resize_image<'a>(
    env: Env<'a>,
    image_term: Term<'a>,
    width: i32,
    height: i32,
) -> NifResult<Term<'a>> {
    if width <= 0 || height <= 0 {
        return Ok((atoms::error(), atoms::invalid_image()).encode(env));
    }
    let image = image_from_term(image_term)?;
    let encoded = render_image_resource(
        &image,
        None,
        Rect::from_xywh(0.0, 0.0, width as f32, height as f32),
    )?;
    Ok((
        atoms::ok(),
        ResourceArc::new(EncodedImage { bytes: encoded }),
    )
        .encode(env))
}

#[rustler::nif(schedule = "DirtyCpu")]
fn crop_image<'a>(
    env: Env<'a>,
    image_term: Term<'a>,
    source: (f64, f64, f64, f64),
) -> NifResult<Term<'a>> {
    let image = image_from_term(image_term)?;
    let src = Rect::from_xywh(
        source.0 as f32,
        source.1 as f32,
        source.2 as f32,
        source.3 as f32,
    );
    let encoded = render_image_resource(
        &image,
        Some(src),
        Rect::from_xywh(0.0, 0.0, src.width(), src.height()),
    )?;
    Ok((
        atoms::ok(),
        ResourceArc::new(EncodedImage { bytes: encoded }),
    )
        .encode(env))
}

#[rustler::nif(schedule = "DirtyCpu")]
fn load_font<'a>(env: Env<'a>, bytes: Binary<'a>) -> NifResult<Term<'a>> {
    if FontMgr::new()
        .new_from_data(bytes.as_slice(), None)
        .is_none()
    {
        return Ok((atoms::error(), atoms::invalid_font()).encode(env));
    }

    Ok((
        atoms::ok(),
        ResourceArc::new(EncodedFont {
            bytes: bytes.as_slice().to_vec(),
        }),
    )
        .encode(env))
}

#[rustler::nif(schedule = "DirtyCpu")]
fn measure_text<'a>(
    env: Env<'a>,
    text: String,
    font_term: Term<'a>,
    size: f64,
) -> NifResult<Term<'a>> {
    let font = font_from_term(font_term, size as f32)?;
    let paint = Paint::default();
    let (width, bounds) = font.measure_str(text, Some(&paint));

    Ok((
        atoms::ok(),
        width,
        bounds.left,
        bounds.top,
        bounds.right,
        bounds.bottom,
    )
        .encode(env))
}

fn image_from_term(image_term: Term) -> NifResult<Image> {
    let image_ref = image_term
        .map_get(Atom::from_bytes(image_term.get_env(), b"ref")?)?
        .decode::<ResourceArc<EncodedImage>>()?;
    Image::from_encoded(Data::new_copy(&image_ref.bytes)).ok_or(rustler::Error::BadArg)
}

fn render_image_resource(image: &Image, src: Option<Rect>, dst: Rect) -> NifResult<Vec<u8>> {
    let width = dst.width().round() as i32;
    let height = dst.height().round() as i32;
    let mut surface = surfaces::raster_n32_premul((width, height)).ok_or(rustler::Error::BadArg)?;
    surface.canvas().clear(Color::TRANSPARENT);
    let paint = Paint::default();
    let source = src
        .as_ref()
        .map(|rect| (rect, skia_safe::canvas::SrcRectConstraint::Strict));
    surface.canvas().draw_image_rect_with_sampling_options(
        image,
        source,
        dst,
        SamplingOptions::from(FilterMode::Linear),
        &paint,
    );
    let snapshot = surface.image_snapshot();
    let data = snapshot
        .encode(None, EncodedImageFormat::PNG, 100)
        .ok_or(rustler::Error::BadArg)?;
    Ok(data.as_bytes().to_vec())
}

fn encode_rendered<'a>(
    env: Env<'a>,
    batch: Term<'a>,
    format: EncodedImageFormat,
    quality: u32,
) -> NifResult<Term<'a>> {
    let mut surface = match render_surface(batch)? {
        Ok(surface) => surface,
        Err(reason) => return Ok((atoms::error(), reason).encode(env)),
    };

    let image = surface.image_snapshot();
    let data = match image.encode(None, format, quality.clamp(0, 100)) {
        Some(data) => data,
        None => return Ok((atoms::error(), atoms::unsupported_format()).encode(env)),
    };

    Ok((atoms::ok(), binary(env, data.as_bytes())?).encode(env))
}

fn render_surface(batch: Term) -> NifResult<Result<skia_safe::Surface, Atom>> {
    let width = batch.map_get(atoms::width())?.decode::<i32>()?;
    let height = batch.map_get(atoms::height())?.decode::<i32>()?;

    if width <= 0 || height <= 0 {
        return Ok(Err(atoms::invalid_batch()));
    }

    let mut surface = match surfaces::raster_n32_premul((width, height)) {
        Some(surface) => surface,
        None => return Ok(Err(atoms::render_failed())),
    };

    surface.canvas().clear(Color::TRANSPARENT);

    for command in batch.map_get(atoms::commands())?.decode::<Vec<Term>>()? {
        draw_command(&mut surface, command)?;
    }

    Ok(Ok(surface))
}

fn draw_command(surface: &mut skia_safe::Surface, command: Term) -> NifResult<()> {
    let op = command.map_get(atoms::op())?.decode::<Atom>()?;

    if op == atoms::clear() {
        draw_clear(surface, command)
    } else if op == atoms::rect() {
        draw_rect(surface, command)
    } else if op == atoms::circle() {
        draw_circle(surface, command)
    } else if op == atoms::line() {
        draw_line(surface, command)
    } else if op == atoms::text() {
        draw_text(surface, command)
    } else if op == atoms::image() {
        draw_image(surface, command)
    } else if op == atoms::path() {
        draw_path(surface, command)
    } else if op == atoms::clip_rect() {
        clip_rect(surface, command)
    } else if op == atoms::clip_circle() {
        clip_circle(surface, command)
    } else if op == atoms::clip_path() {
        clip_path(surface, command)
    } else if op == atoms::save() {
        surface.canvas().save();
        Ok(())
    } else if op == atoms::save_layer() {
        let opts = decode_opts(command)?;
        let layer_opts = generated_opts::decode_save_layer_opts(&opts)?;
        surface
            .canvas()
            .save_layer_alpha_f(None, layer_opts.opacity.unwrap_or(1.0).clamp(0.0, 1.0));
        Ok(())
    } else if op == atoms::restore() {
        surface.canvas().restore();
        Ok(())
    } else if op == atoms::translate() {
        let opts = decode_opts(command)?;
        let translate_opts = generated_opts::decode_translate_opts(&opts)?;
        surface
            .canvas()
            .translate((translate_opts.x, translate_opts.y));
        Ok(())
    } else if op == atoms::rotate() {
        let opts = decode_opts(command)?;
        let rotate_opts = generated_opts::decode_rotate_opts(&opts)?;
        surface.canvas().rotate(rotate_opts.degrees, None);
        Ok(())
    } else {
        Ok(())
    }
}

fn draw_clear(surface: &mut skia_safe::Surface, command: Term) -> NifResult<()> {
    let args = command.map_get(atoms::args())?.decode::<Vec<Term>>()?;

    if let Some(color) = args.first().and_then(|term| decode_color(*term).ok()) {
        surface.canvas().clear(color);
    }

    Ok(())
}

fn draw_rect(surface: &mut skia_safe::Surface, command: Term) -> NifResult<()> {
    let opts = decode_opts(command)?;
    let rect_opts = generated_opts::decode_rect_opts(&opts)?;
    let rect = Rect::from_xywh(rect_opts.x, rect_opts.y, rect_opts.width, rect_opts.height);
    draw_rect_shape(surface, rect, rect_opts.radius.unwrap_or(0.0), &opts)
}

fn draw_circle(surface: &mut skia_safe::Surface, command: Term) -> NifResult<()> {
    let opts = decode_opts(command)?;
    let circle_opts = generated_opts::decode_circle_opts(&opts)?;
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

fn draw_line(surface: &mut skia_safe::Surface, command: Term) -> NifResult<()> {
    let opts = decode_opts(command)?;
    let line_opts = generated_opts::decode_line_opts(&opts)?;
    let color = decode_color(line_opts.stroke)?;
    let paint = stroke_paint(color, line_opts.stroke_width.unwrap_or(1.0), &opts)?;

    surface.canvas().draw_line(
        point_from_term(line_opts.from)?,
        point_from_term(line_opts.to)?,
        &paint,
    );
    Ok(())
}

fn draw_text(surface: &mut skia_safe::Surface, command: Term) -> NifResult<()> {
    let args = command.map_get(atoms::args())?.decode::<Vec<Term>>()?;
    let text = args
        .first()
        .ok_or(rustler::Error::BadArg)?
        .decode::<String>()?;
    let opts = decode_opts(command)?;
    let text_opts = generated_opts::decode_text_opts(&opts)?;
    let size = text_opts.size.unwrap_or(16.0);
    let mut font = match text_opts.font {
        Some(term) => font_from_term(term, size)?,
        None => Font::default(),
    };
    font.set_size(size);
    let paint = match text_opts.fill {
        Some(term) => fill_paint(decode_color(term)?),
        None => fill_paint(Color::BLACK),
    };

    surface
        .canvas()
        .draw_str(text, (text_opts.x, text_opts.y), &font, &paint);
    Ok(())
}

fn draw_image(surface: &mut skia_safe::Surface, command: Term) -> NifResult<()> {
    let args = command.map_get(atoms::args())?.decode::<Vec<Term>>()?;
    let image = image_from_term(*args.first().ok_or(rustler::Error::BadArg)?)?;
    let opts = decode_opts(command)?;
    let image_opts = generated_opts::decode_image_opts(&opts)?;
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

fn draw_path(surface: &mut skia_safe::Surface, command: Term) -> NifResult<()> {
    let args = command.map_get(atoms::args())?.decode::<Vec<Term>>()?;
    let mut path = build_path(*args.first().ok_or(rustler::Error::BadArg)?)?;
    let opts = decode_opts(command)?;
    let path_opts = generated_opts::decode_path_opts(&opts)?;
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

fn clip_rect(surface: &mut skia_safe::Surface, command: Term) -> NifResult<()> {
    let opts = decode_opts(command)?;
    let clip_opts = generated_opts::decode_clip_rect_opts(&opts)?;
    let rect = Rect::from_xywh(clip_opts.x, clip_opts.y, clip_opts.width, clip_opts.height);
    let radius = clip_opts.radius.unwrap_or(0.0);
    let antialias = clip_opts.antialias.unwrap_or(true);

    if radius > 0.0 {
        surface
            .canvas()
            .clip_rrect(RRect::new_rect_xy(rect, radius, radius), None, antialias);
    } else {
        surface.canvas().clip_rect(rect, None, antialias);
    }

    Ok(())
}

fn clip_circle(surface: &mut skia_safe::Surface, command: Term) -> NifResult<()> {
    let opts = decode_opts(command)?;
    let clip_opts = generated_opts::decode_clip_circle_opts(&opts)?;
    let mut builder = PathBuilder::new();
    builder.add_circle(Point::new(clip_opts.x, clip_opts.y), clip_opts.radius, None);
    surface
        .canvas()
        .clip_path(&builder.detach(), None, clip_opts.antialias.unwrap_or(true));
    Ok(())
}

fn clip_path(surface: &mut skia_safe::Surface, command: Term) -> NifResult<()> {
    let args = command.map_get(atoms::args())?.decode::<Vec<Term>>()?;
    let mut path = build_path(*args.first().ok_or(rustler::Error::BadArg)?)?;
    let opts = decode_opts(command)?;
    let clip_opts = generated_opts::decode_clip_path_opts(&opts)?;
    apply_fill_rule(&mut path, &opts)?;
    surface
        .canvas()
        .clip_path(&path, None, clip_opts.antialias.unwrap_or(true));
    Ok(())
}

fn build_path(path_term: Term) -> NifResult<skia_safe::Path> {
    let segments = path_term
        .map_get(atoms::segments())?
        .decode::<Vec<Term>>()?;
    let mut builder = PathBuilder::new();

    for segment in segments.into_iter().rev() {
        if let Ok(op) = segment.decode::<Atom>() {
            if op == atoms::close() {
                builder.close();
            }
        } else if let Ok((op, x, y)) = segment.decode::<(Atom, f64, f64)>() {
            if op == atoms::move_to() {
                builder.move_to((x as f32, y as f32));
            } else if op == atoms::line_to() {
                builder.line_to((x as f32, y as f32));
            }
        } else if let Ok((op, cx, cy, x, y)) = segment.decode::<(Atom, f64, f64, f64, f64)>() {
            if op == atoms::quad_to() {
                builder.quad_to((cx as f32, cy as f32), (x as f32, y as f32));
            }
        } else if let Ok((op, c1x, c1y, c2x, c2y, x, y)) =
            segment.decode::<(Atom, f64, f64, f64, f64, f64, f64)>()
        {
            if op == atoms::cubic_to() {
                builder.cubic_to(
                    (c1x as f32, c1y as f32),
                    (c2x as f32, c2y as f32),
                    (x as f32, y as f32),
                );
            }
        }
    }

    Ok(builder.detach())
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

fn fill_paint(color: Color) -> Paint {
    let mut paint = Paint::default();
    paint
        .set_anti_alias(true)
        .set_style(PaintStyle::Fill)
        .set_color(color);
    paint
}

fn stroke_paint(color: Color, width: f32, opts: &[(Atom, Term)]) -> NifResult<Paint> {
    let mut paint = Paint::default();
    paint
        .set_anti_alias(true)
        .set_style(PaintStyle::Stroke)
        .set_stroke_width(width)
        .set_color(color);
    apply_stroke_options(&mut paint, opts)?;
    apply_blend_mode(&mut paint, opts)?;
    Ok(paint)
}

fn apply_stroke_options(paint: &mut Paint, opts: &[(Atom, Term)]) -> NifResult<()> {
    if let Some(term) = opt_term(opts, atoms::stroke_cap()) {
        let cap = term.decode::<Atom>()?;
        if cap == atoms::butt() {
            paint.set_stroke_cap(paint::Cap::Butt);
        } else if cap == atoms::round() {
            paint.set_stroke_cap(paint::Cap::Round);
        } else if cap == atoms::square() {
            paint.set_stroke_cap(paint::Cap::Square);
        } else {
            return Err(rustler::Error::BadArg);
        }
    }

    if let Some(term) = opt_term(opts, atoms::stroke_join()) {
        let join = term.decode::<Atom>()?;
        if join == atoms::miter() {
            paint.set_stroke_join(paint::Join::Miter);
        } else if join == atoms::round() {
            paint.set_stroke_join(paint::Join::Round);
        } else if join == atoms::bevel() {
            paint.set_stroke_join(paint::Join::Bevel);
        } else {
            return Err(rustler::Error::BadArg);
        }
    }

    if let Some(miter) = opt_f32_option(opts, atoms::stroke_miter())? {
        paint.set_stroke_miter(miter);
    }

    Ok(())
}

fn apply_blend_mode(paint: &mut Paint, opts: &[(Atom, Term)]) -> NifResult<()> {
    if let Some(term) = opt_term(opts, atoms::blend_mode()) {
        paint.set_blend_mode(decode_blend_mode(term.decode::<Atom>()?)?);
    }
    Ok(())
}

fn decode_blend_mode(mode: Atom) -> NifResult<BlendMode> {
    if mode == atoms::src_over() {
        Ok(BlendMode::SrcOver)
    } else if mode == atoms::multiply() {
        Ok(BlendMode::Multiply)
    } else if mode == atoms::screen() {
        Ok(BlendMode::Screen)
    } else if mode == atoms::overlay() {
        Ok(BlendMode::Overlay)
    } else if mode == atoms::darken() {
        Ok(BlendMode::Darken)
    } else if mode == atoms::lighten() {
        Ok(BlendMode::Lighten)
    } else if mode == atoms::clear_mode() {
        Ok(BlendMode::Clear)
    } else {
        Err(rustler::Error::BadArg)
    }
}

fn apply_fill_rule(path: &mut skia_safe::Path, opts: &[(Atom, Term)]) -> NifResult<()> {
    if let Some(term) = opt_term(opts, atoms::fill_rule()) {
        let rule = term.decode::<Atom>()?;
        if rule == atoms::winding() {
            path.set_fill_type(PathFillType::Winding);
        } else if rule == atoms::even_odd() {
            path.set_fill_type(PathFillType::EvenOdd);
        } else {
            return Err(rustler::Error::BadArg);
        }
    }
    Ok(())
}

fn binary<'a>(env: Env<'a>, bytes: &[u8]) -> NifResult<Binary<'a>> {
    let mut owned =
        OwnedBinary::new(bytes.len()).ok_or(rustler::Error::Term(Box::new("alloc_failed")))?;
    owned.as_mut_slice().copy_from_slice(bytes);
    Ok(Binary::from_owned(owned, env))
}

fn decode_opts<'a>(command: Term<'a>) -> NifResult<Vec<(Atom, Term<'a>)>> {
    command
        .map_get(atoms::opts())?
        .decode::<Vec<(Atom, Term<'a>)>>()
}

fn opt_f32<'a>(opts: &[(Atom, Term<'a>)], key: Atom) -> NifResult<f32> {
    opt_f32_default(opts, key, f32::NAN).and_then(|value| {
        if value.is_nan() {
            Err(rustler::Error::BadArg)
        } else {
            Ok(value)
        }
    })
}

fn opt_f32_option<'a>(opts: &[(Atom, Term<'a>)], key: Atom) -> NifResult<Option<f32>> {
    match opt_term(opts, key) {
        Some(term) => Ok(Some(term.decode::<f64>()? as f32)),
        None => Ok(None),
    }
}

fn opt_f32_default<'a>(opts: &[(Atom, Term<'a>)], key: Atom, default: f32) -> NifResult<f32> {
    match opt_term(opts, key) {
        Some(term) => Ok(term.decode::<f64>()? as f32),
        None => Ok(default),
    }
}

fn opt_bool_option<'a>(opts: &[(Atom, Term<'a>)], key: Atom) -> NifResult<Option<bool>> {
    match opt_term(opts, key) {
        Some(term) => Ok(Some(term.decode::<bool>()?)),
        None => Ok(None),
    }
}

fn opt_atom_option<'a>(opts: &[(Atom, Term<'a>)], key: Atom) -> NifResult<Option<Atom>> {
    match opt_term(opts, key) {
        Some(term) => Ok(Some(term.decode::<Atom>()?)),
        None => Ok(None),
    }
}

fn point_from_term(term: Term) -> NifResult<Point> {
    let (x, y) = term.decode::<(f64, f64)>()?;
    Ok(Point::new(x as f32, y as f32))
}

fn rect_from_term(term: Term) -> NifResult<Rect> {
    let (x, y, width, height) = term.decode::<(f64, f64, f64, f64)>()?;
    Ok(Rect::from_xywh(
        x as f32,
        y as f32,
        width as f32,
        height as f32,
    ))
}

fn opt_sampling<'a>(opts: &[(Atom, Term<'a>)], key: Atom) -> NifResult<SamplingOptions> {
    match opt_term(opts, key) {
        Some(term) => {
            let sampling = term.decode::<Atom>()?;
            if sampling == atoms::linear() {
                Ok(SamplingOptions::from(FilterMode::Linear))
            } else if sampling == atoms::nearest() {
                Ok(SamplingOptions::from(FilterMode::Nearest))
            } else {
                Err(rustler::Error::BadArg)
            }
        }
        None => Ok(SamplingOptions::default()),
    }
}

fn opt_fill_paint<'a>(opts: &[(Atom, Term<'a>)], key: Atom) -> NifResult<Option<Paint>> {
    match opt_term(opts, key) {
        Some(term) => Ok(Some(decode_paint(term)?)),
        None => Ok(None),
    }
}

fn opt_color<'a>(opts: &[(Atom, Term<'a>)], key: Atom) -> NifResult<Option<Color>> {
    match opt_term(opts, key) {
        Some(term) => Ok(Some(decode_color(term)?)),
        None => Ok(None),
    }
}

fn font_from_term(term: Term, size: f32) -> NifResult<Font> {
    if term.decode::<Atom>().is_ok_and(|atom| atom == atoms::nil()) {
        let typeface = FontMgr::new()
            .legacy_make_typeface(None, FontStyle::normal())
            .ok_or(rustler::Error::BadArg)?;
        return Ok(Font::new(typeface, size));
    }

    let font_ref = term
        .map_get(Atom::from_bytes(term.get_env(), b"ref")?)?
        .decode::<ResourceArc<EncodedFont>>()?;
    let typeface = FontMgr::new()
        .new_from_data(&font_ref.bytes, None)
        .ok_or(rustler::Error::BadArg)?;
    Ok(Font::new(typeface, size))
}

fn decode_paint(term: Term) -> NifResult<Paint> {
    if let Ok(color) = decode_color(term) {
        return Ok(fill_paint(color));
    }

    if let Ok((tag, from, to, colors)) = term.decode::<(Atom, (f64, f64), (f64, f64), Vec<Term>)>()
    {
        if tag == atoms::linear_gradient() {
            let colors = decode_colors(colors)?;
            let mut paint = Paint::default();
            paint.set_anti_alias(true).set_style(PaintStyle::Fill);
            if let Some(shader) = Shader::linear_gradient(
                ((from.0 as f32, from.1 as f32), (to.0 as f32, to.1 as f32)),
                colors.as_slice(),
                None,
                TileMode::Clamp,
                None,
                None,
            ) {
                paint.set_shader(shader);
            }
            return Ok(paint);
        }
    }

    if let Ok((tag, center, radius, colors)) = term.decode::<(Atom, (f64, f64), f64, Vec<Term>)>() {
        if tag == atoms::radial_gradient() {
            let colors = decode_colors(colors)?;
            let mut paint = Paint::default();
            paint.set_anti_alias(true).set_style(PaintStyle::Fill);
            if let Some(shader) = Shader::radial_gradient(
                (center.0 as f32, center.1 as f32),
                radius as f32,
                colors.as_slice(),
                None,
                TileMode::Clamp,
                None,
                None,
            ) {
                paint.set_shader(shader);
            }
            return Ok(paint);
        }
    }

    Err(rustler::Error::BadArg)
}

fn decode_colors(colors: Vec<Term>) -> NifResult<Vec<Color>> {
    colors.into_iter().map(decode_color).collect()
}

fn opt_term<'a>(opts: &[(Atom, Term<'a>)], key: Atom) -> Option<Term<'a>> {
    opts.iter()
        .find_map(|(option_key, value)| (*option_key == key).then_some(*value))
}

fn decode_color(term: Term) -> NifResult<Color> {
    let (tag, red, green, blue, alpha) = term.decode::<(Atom, u8, u8, u8, u8)>()?;

    if tag == atoms::rgba() {
        Ok(Color::from_argb(alpha, red, green, blue))
    } else {
        Err(rustler::Error::BadArg)
    }
}

rustler::init!("Elixir.Skia.Native");
