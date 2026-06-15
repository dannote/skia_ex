#![allow(deprecated)]

use rustler::{Atom, Binary, Encoder, Env, NifResult, OwnedBinary, ResourceArc, Term};
use skia_safe::{
    canvas::SaveLayerRec,
    image_filters, path_utils, surfaces,
    textlayout::{FontCollection, ParagraphBuilder, ParagraphStyle, TextAlign, TextDirection, TextStyle},
    color_filters, AlphaType, Color, ColorFilter, ColorType, CubicResampler, Data,
    EncodedImageFormat, FilterMode, Font, FontMgr, FontStyle, IPoint, Image, ImageInfo, Matrix,
    Paint, PaintStyle, PathBuilder, PathDirection, PathEffect, Point, RRect, Rect, SamplingOptions,
    Shader, TileMode,
};

include!("generated_resources.rs");

mod atoms {
    include!("generated_atoms.rs");
}

mod generated_enums;
mod generated_opts;

include!("generated_nifs.rs");

fn render_png_impl<'a>(env: Env<'a>, batch: Term<'a>) -> NifResult<Term<'a>> {
    encode_rendered(env, batch, EncodedImageFormat::PNG, 100)
}

fn render_jpeg_impl<'a>(env: Env<'a>, batch: Term<'a>, quality: u32) -> NifResult<Term<'a>> {
    encode_rendered(env, batch, EncodedImageFormat::JPEG, quality)
}

fn render_webp_impl<'a>(env: Env<'a>, batch: Term<'a>, quality: u32) -> NifResult<Term<'a>> {
    encode_rendered(env, batch, EncodedImageFormat::WEBP, quality)
}

fn render_rgba_impl<'a>(env: Env<'a>, batch: Term<'a>) -> NifResult<Term<'a>> {
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

fn decode_image_impl<'a>(env: Env<'a>, bytes: Binary<'a>) -> NifResult<Term<'a>> {
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

fn encode_image_impl<'a>(
    env: Env<'a>,
    image_term: Term<'a>,
    format: Atom,
    quality: u32,
) -> NifResult<Term<'a>> {
    let image = image_from_term(image_term)?;
    let format = match generated_enums::decode_encoded_image_format(format) {
        Ok(format) => format,
        Err(_) => return Ok((atoms::error(), atoms::unsupported_format()).encode(env)),
    };

    match image.encode(None, format, quality.clamp(0, 100)) {
        Some(data) => Ok((atoms::ok(), binary(env, data.as_bytes())?).encode(env)),
        None => Ok((atoms::error(), atoms::unsupported_format()).encode(env)),
    }
}

fn resize_image_impl<'a>(
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

fn crop_image_impl<'a>(
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

fn load_font_impl<'a>(env: Env<'a>, bytes: Binary<'a>) -> NifResult<Term<'a>> {
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

fn measure_text_impl<'a>(
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

fn path_to_svg_impl<'a>(env: Env<'a>, path_term: Term<'a>) -> NifResult<Term<'a>> {
    match build_path(path_term) {
        Ok(path) => Ok((atoms::ok(), path.to_svg()).encode(env)),
        Err(_) => Ok((atoms::error(), rustler::types::atom::badarg()).encode(env)),
    }
}

fn image_from_term(image_term: Term) -> NifResult<Image> {
    let image_ref = decode_encoded_image_ref(image_term)?;
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

include!("generated_dispatch.rs");
include!("generated_handlers.rs");
include!("generated_style_helpers.rs");
include!("generated_layers.rs");
include!("generated_transforms.rs");
include!("generated_shapes.rs");
include!("generated_text.rs");
include!("generated_images.rs");
include!("generated_draw_paths.rs");
include!("generated_clips.rs");
include!("generated_path.rs");
include!("generated_paint.rs");

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

fn binary<'a>(env: Env<'a>, bytes: &[u8]) -> NifResult<Binary<'a>> {
    let mut owned =
        OwnedBinary::new(bytes.len()).ok_or(rustler::Error::Term(Box::new("alloc_failed")))?;
    owned.as_mut_slice().copy_from_slice(bytes);
    Ok(Binary::from_owned(owned, env))
}

include!("generated_opts_helpers.rs");

fn point_from_term(term: Term) -> NifResult<Point> {
    let (x, y) = term.decode::<(f64, f64)>()?;
    Ok(Point::new(x as f32, y as f32))
}

fn matrix_from_term(term: Term) -> NifResult<Matrix> {
    let (m00, m01, m02, m10, m11, m12) = term.decode::<(f64, f64, f64, f64, f64, f64)>()?;
    Ok(Matrix::new_all(
        m00 as f32, m01 as f32, m02 as f32, m10 as f32, m11 as f32, m12 as f32, 0.0, 0.0, 1.0,
    ))
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
        Some(term) => decode_sampling_options(term),
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

    let font_ref = decode_encoded_font_ref(term)?;
    let typeface = FontMgr::new()
        .new_from_data(&font_ref.bytes, None)
        .ok_or(rustler::Error::BadArg)?;
    Ok(Font::new(typeface, size))
}

rustler::init!("Elixir.Skia.Native");
