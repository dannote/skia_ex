#![allow(deprecated)]

use rustler::{Atom, Binary, Encoder, Env, NifResult, OwnedBinary, ResourceArc, Term};
use rustler::types::map::map_new;
use skia_safe::{
    canvas::{SaveLayerRec, SrcRectConstraint},
    font_style::{Slant, Weight, Width},
    vertices::VertexMode,
    image_filters, path_utils, surfaces,
    textlayout::{FontCollection, ParagraphBuilder, ParagraphStyle, TextAlign, TextDecoration,
        TextDecorationMode as DecorationMode, TextDecorationStyle, TextDirection, TextStyle, TypefaceFontProvider},
    color_filters, AlphaType, Color, ColorFilter, ColorType, CubicResampler, Data,
    runtime_effect::ChildPtr,
    ClipOp, EncodedImageFormat, FilterMode, Font, FontMgr, FontStyle, IPoint, Image, ImageInfo, MaskFilter, Matrix,
    Paint, PaintStyle, PathBuilder, PathDirection, PathEffect, Picture, PictureRecorder, Point, RRect,
    Rect, RuntimeEffect, SamplingOptions, Shader, TextBlob, TileMode, Vertices,
};

include!("generated_resources.rs");

mod atoms {
    include!("generated_atoms.rs");
}

mod generated_enums;
mod generated_opts;

include!("generated_nifs.rs");

fn compile_runtime_effect_impl<'a>(env: Env<'a>, source: String) -> NifResult<Term<'a>> {
    match RuntimeEffect::make_for_shader(&source, None) {
        Ok(_) => Ok((atoms::ok(), ResourceArc::new(EncodedRuntimeEffect { source })).encode(env)),
        Err(error) => Ok((atoms::error(), error).encode(env)),
    }
}

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
    encode_rgba_surface(env, batch, render_surface)
}

fn render_compact_png_impl<'a>(env: Env<'a>, batch: Term<'a>) -> NifResult<Term<'a>> {
    let mut surface = match render_compact_surface(env, batch)? {
        Ok(surface) => surface,
        Err(reason) => return Ok((atoms::error(), reason).encode(env)),
    };

    let image = surface.image_snapshot();
    let data = match image.encode(None, EncodedImageFormat::PNG, 100) {
        Some(data) => data,
        None => return Ok((atoms::error(), atoms::unsupported_format()).encode(env)),
    };

    Ok((atoms::ok(), binary(env, data.as_bytes())?).encode(env))
}

fn render_compact_rgba_impl<'a>(env: Env<'a>, batch: Term<'a>) -> NifResult<Term<'a>> {
    encode_rgba_surface(env, batch, |batch| render_compact_surface(env, batch))
}

fn encode_rgba_surface<'a, F>(
    env: Env<'a>,
    batch: Term<'a>,
    render: F,
) -> NifResult<Term<'a>>
where
    F: FnOnce(Term<'a>) -> NifResult<Result<skia_safe::Surface, Atom>>,
{
    let width = batch_width(batch)?;
    let height = batch_height(batch)?;
    let mut surface = match render(batch)? {
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

    let width = image.width();
    let height = image.height();
    let resource = ResourceArc::new(EncodedImage { image });

    Ok((atoms::ok(), resource, width, height).encode(env))
}

fn encode_image_impl<'a>(
    env: Env<'a>,
    image_term: Term<'a>,
    format: Atom,
    quality: u32,
) -> NifResult<Term<'a>> {
    let image = match image_from_term(image_term) {
        Ok(image) => image,
        Err(_) => return Ok((atoms::error(), atoms::invalid_image()).encode(env)),
    };
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
    let image = match image_from_term(image_term) {
        Ok(image) => image,
        Err(_) => return Ok((atoms::error(), atoms::invalid_image()).encode(env)),
    };
    let encoded = render_image_resource(
        &image,
        None,
        Rect::from_xywh(0.0, 0.0, width as f32, height as f32),
    )?;
    let image = Image::from_encoded(Data::new_copy(&encoded)).ok_or(rustler::Error::BadArg)?;
    Ok((
        atoms::ok(),
        ResourceArc::new(EncodedImage { image }),
    )
        .encode(env))
}

fn crop_image_impl<'a>(
    env: Env<'a>,
    image_term: Term<'a>,
    source: (f64, f64, f64, f64),
) -> NifResult<Term<'a>> {
    let image = match image_from_term(image_term) {
        Ok(image) => image,
        Err(_) => return Ok((atoms::error(), atoms::invalid_image()).encode(env)),
    };
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
    let image = Image::from_encoded(Data::new_copy(&encoded)).ok_or(rustler::Error::BadArg)?;
    Ok((
        atoms::ok(),
        ResourceArc::new(EncodedImage { image }),
    )
        .encode(env))
}

fn load_font_impl<'a>(env: Env<'a>, bytes: Binary<'a>) -> NifResult<Term<'a>> {
    let Some(typeface) = FontMgr::new().new_from_data(bytes.as_slice(), None) else {
        return Ok((atoms::error(), atoms::invalid_font()).encode(env));
    };
    let family = typeface.family_name();

    Ok((
        atoms::ok(),
        ResourceArc::new(EncodedFont { typeface }),
        family,
    )
        .encode(env))
}

fn font_families_impl<'a>(env: Env<'a>) -> NifResult<Term<'a>> {
    let families: Vec<String> = FontMgr::new().family_names().collect();
    Ok((atoms::ok(), families).encode(env))
}

fn match_font_impl<'a>(env: Env<'a>, family: String, weight: i32, slant: Atom) -> NifResult<Term<'a>> {
    let style = font_style(weight, slant);
    let Some(typeface) = FontMgr::new().match_family_style(family, style) else {
        return Ok((atoms::error(), atoms::invalid_font()).encode(env));
    };

    Ok((
        atoms::ok(),
        ResourceArc::new(EncodedFont { typeface }),
    )
        .encode(env))
}

fn match_font_character_impl<'a>(
    env: Env<'a>,
    family: String,
    weight: i32,
    slant: Atom,
    languages: Vec<String>,
    character: u32,
) -> NifResult<Term<'a>> {
    if character > 0x10FFFF || (0xD800..=0xDFFF).contains(&character) {
        return Ok((atoms::error(), atoms::invalid_font()).encode(env));
    }

    let style = font_style(weight, slant);
    let language_refs: Vec<&str> = languages.iter().map(String::as_str).collect();
    let Some(typeface) = FontMgr::new().match_family_style_character(
        family,
        style,
        &language_refs,
        character as i32,
    ) else {
        return Ok((atoms::error(), atoms::invalid_font()).encode(env));
    };
    let matched_family = typeface.family_name();

    Ok((
        atoms::ok(),
        ResourceArc::new(EncodedFont { typeface }),
        matched_family,
    )
        .encode(env))
}

fn font_style(weight: i32, slant: Atom) -> FontStyle {
    let slant = if slant == atoms::italic() {
        Slant::Italic
    } else if slant == atoms::oblique() {
        Slant::Oblique
    } else {
        Slant::Upright
    };

    FontStyle::new(Weight::from(weight), Width::NORMAL, slant)
}

fn typeface_info_impl<'a>(env: Env<'a>, typeface_term: Term<'a>) -> NifResult<Term<'a>> {
    let typeface_ref = match decode_encoded_font_ref(typeface_term) {
        Ok(typeface_ref) => typeface_ref,
        Err(_) => return Ok((atoms::error(), atoms::invalid_font()).encode(env)),
    };
    let typeface = &typeface_ref.typeface;
    let style = typeface.font_style();
    let slant = match style.slant() {
        Slant::Italic => atoms::italic(),
        Slant::Oblique => atoms::oblique(),
        _ => atoms::normal(),
    };

    Ok((
        atoms::ok(),
        (
            typeface.unique_id() as i64,
            *style.weight() as i64,
            *style.width() as i64,
            slant,
            typeface.is_bold(),
            typeface.is_italic(),
            typeface.is_fixed_pitch(),
        ),
    )
        .encode(env))
}

fn font_metrics_impl<'a>(env: Env<'a>, font_term: Term<'a>) -> NifResult<Term<'a>> {
    let font = match font_from_term(font_term, 16.0) {
        Ok(font) => font,
        Err(_) => return Ok((atoms::error(), atoms::invalid_font()).encode(env)),
    };
    let (line_spacing, metrics) = font.metrics();

    Ok((
        atoms::ok(),
        vec![
            line_spacing,
            metrics.top,
            metrics.ascent,
            metrics.descent,
            metrics.bottom,
            metrics.leading,
            metrics.avg_char_width,
            metrics.max_char_width,
            metrics.x_min,
            metrics.x_max,
            metrics.x_height,
            metrics.cap_height,
        ],
    )
        .encode(env))
}

fn font_glyph_ids_impl<'a>(env: Env<'a>, font_term: Term<'a>, text: String) -> NifResult<Term<'a>> {
    let font = match font_from_term(font_term, 16.0) {
        Ok(font) => font,
        Err(_) => return Ok((atoms::error(), atoms::invalid_font()).encode(env)),
    };
    let glyphs: Vec<u16> = font.str_to_glyphs_vec(text).into_iter().collect();
    Ok((atoms::ok(), glyphs).encode(env))
}

fn measure_text_impl<'a>(
    env: Env<'a>,
    text: String,
    font_term: Term<'a>,
    size: f64,
) -> NifResult<Term<'a>> {
    let font = match font_from_term(font_term, size as f32) {
        Ok(font) => font,
        Err(_) => return Ok((atoms::error(), atoms::invalid_font()).encode(env)),
    };
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

fn create_text_blob_impl<'a>(
    env: Env<'a>,
    text: String,
    font_term: Term<'a>,
    size: f64,
) -> NifResult<Term<'a>> {
    let font = match font_from_term(font_term, size as f32) {
        Ok(font) => font,
        Err(_) => return Ok((atoms::error(), atoms::invalid_font()).encode(env)),
    };
    let Some(blob) = TextBlob::from_str(text, &font) else {
        return Ok((atoms::error(), atoms::invalid_text_blob()).encode(env));
    };

    Ok((atoms::ok(), ResourceArc::new(EncodedTextBlob { blob })).encode(env))
}

fn text_blob_bounds_impl<'a>(env: Env<'a>, blob_term: Term<'a>) -> NifResult<Term<'a>> {
    let blob = match text_blob_from_term(blob_term) {
        Ok(blob) => blob,
        Err(_) => return Ok((atoms::error(), atoms::invalid_text_blob()).encode(env)),
    };
    let bounds = blob.bounds();
    Ok((atoms::ok(), (bounds.left, bounds.top, bounds.right, bounds.bottom)).encode(env))
}

fn path_to_svg_impl<'a>(env: Env<'a>, path_term: Term<'a>) -> NifResult<Term<'a>> {
    match build_path(path_term) {
        Ok(path) => Ok((atoms::ok(), path.to_svg()).encode(env)),
        Err(_) => Ok((atoms::error(), atoms::invalid_path()).encode(env)),
    }
}

fn record_picture_impl<'a>(env: Env<'a>, batch: Term<'a>) -> NifResult<Term<'a>> {
    let width = batch.map_get(atoms::width())?.decode::<i32>()?;
    let height = batch.map_get(atoms::height())?.decode::<i32>()?;

    if width <= 0 || height <= 0 {
        return Ok((atoms::error(), atoms::invalid_batch()).encode(env));
    }

    let mut recorder = PictureRecorder::new();
    {
        let canvas = recorder.begin_recording(Rect::from_xywh(0.0, 0.0, width as f32, height as f32), false);
        canvas.clear(Color::TRANSPARENT);

        for command in batch.map_get(atoms::commands())?.decode::<Vec<Term>>()? {
            if let Err(reason) = draw_command_result(canvas, command)? {
                return Ok((atoms::error(), reason).encode(env));
            }
        }
    }

    let Some(picture) = recorder.finish_recording_as_picture(None) else {
        return Ok((atoms::error(), atoms::render_failed()).encode(env));
    };

    Ok((
        atoms::ok(),
        ResourceArc::new(EncodedPicture {
            bytes: picture.serialize().as_bytes().to_vec(),
            picture,
        }),
    )
        .encode(env))
}

fn decode_picture_impl<'a>(env: Env<'a>, bytes: Binary<'a>) -> NifResult<Term<'a>> {
    let Some(picture) = Picture::from_bytes(bytes.as_slice()) else {
        return Ok((atoms::error(), atoms::invalid_picture()).encode(env));
    };

    Ok((
        atoms::ok(),
        ResourceArc::new(EncodedPicture {
            bytes: bytes.as_slice().to_vec(),
            picture,
        }),
    )
        .encode(env))
}

fn encode_picture_impl<'a>(env: Env<'a>, picture_term: Term<'a>) -> NifResult<Term<'a>> {
    let picture_ref = match decode_encoded_picture_ref(picture_term) {
        Ok(picture_ref) => picture_ref,
        Err(_) => return Ok((atoms::error(), atoms::invalid_picture()).encode(env)),
    };
    Ok((atoms::ok(), binary(env, &picture_ref.bytes)?).encode(env))
}

fn picture_info_impl<'a>(env: Env<'a>, picture_term: Term<'a>) -> NifResult<Term<'a>> {
    let picture = match picture_from_term(picture_term) {
        Ok(picture) => picture,
        Err(_) => return Ok((atoms::error(), atoms::invalid_picture()).encode(env)),
    };
    let cull = picture.cull_rect();

    Ok((
        atoms::ok(),
        (
            cull.left,
            cull.top,
            cull.right,
            cull.bottom,
            picture.approximate_op_count() as i64,
            picture.approximate_op_count_nested(true) as i64,
            picture.approximate_bytes_used() as i64,
        ),
    )
        .encode(env))
}

fn image_from_term(image_term: Term) -> NifResult<Image> {
    let image_ref = decode_encoded_image_ref(image_term)?;
    Ok(image_ref.image.clone())
}

fn picture_from_term(picture_term: Term) -> NifResult<Picture> {
    let picture_ref = decode_encoded_picture_ref(picture_term)?;
    Ok(picture_ref.picture.clone())
}

fn text_blob_from_term(blob_term: Term) -> NifResult<TextBlob> {
    let blob_ref = decode_encoded_text_blob_ref(blob_term)?;
    Ok(blob_ref.blob.clone())
}

fn runtime_effect_from_term(effect_term: Term) -> NifResult<RuntimeEffect> {
    let effect_ref = decode_encoded_runtime_effect_ref(effect_term)?;
    RuntimeEffect::make_for_shader(&effect_ref.source, None).map_err(|_| rustler::Error::BadArg)
}

fn vertices_from_term(term: Term) -> NifResult<Vertices> {
    let (mode, positions, colors, indices_term) = term.decode::<(Atom, Vec<(f64, f64)>, Vec<Term>, Term)>()?;
    let mode = if mode == atoms::triangle_strip() {
        VertexMode::TriangleStrip
    } else if mode == atoms::triangle_fan() {
        VertexMode::TriangleFan
    } else {
        VertexMode::Triangles
    };
    let positions: Vec<Point> = positions
        .into_iter()
        .map(|(x, y)| Point::new(x as f32, y as f32))
        .collect();
    let colors: Vec<Color> = colors
        .into_iter()
        .map(decode_color)
        .collect::<NifResult<Vec<Color>>>()?;
    let texs = positions.clone();
    let indices = if indices_term.decode::<Atom>().is_ok_and(|atom| atom == atoms::nil()) {
        None
    } else {
        Some(indices_term.decode::<Vec<u16>>()?)
    };

    Ok(Vertices::new_copy(mode, &positions, &texs, &colors, indices.as_deref()))
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
    let width = batch_width(batch)?;
    let height = batch_height(batch)?;

    let mut surface = match new_surface(width, height) {
        Ok(surface) => surface,
        Err(reason) => return Ok(Err(reason)),
    };

    for command in batch.map_get(atoms::commands())?.decode::<Vec<Term>>()? {
        if let Err(reason) = draw_command_result(surface.canvas(), command)? {
            return Ok(Err(reason));
        }
    }

    Ok(Ok(surface))
}

fn render_compact_surface<'a>(env: Env<'a>, batch: Term<'a>) -> NifResult<Result<skia_safe::Surface, Atom>> {
    let width = batch_width(batch)?;
    let height = batch_height(batch)?;

    let mut surface = match new_surface(width, height) {
        Ok(surface) => surface,
        Err(reason) => return Ok(Err(reason)),
    };

    let (_, _, commands) = batch.decode::<(i32, i32, Vec<Term>)>()?;
    for command in commands {
        let command = command_from_compact(env, command)?;
        if let Err(reason) = draw_command_result(surface.canvas(), command)? {
            return Ok(Err(reason));
        }
    }

    Ok(Ok(surface))
}

fn new_surface(width: i32, height: i32) -> Result<skia_safe::Surface, Atom> {
    if width <= 0 || height <= 0 {
        return Err(atoms::invalid_batch());
    }

    let mut surface = surfaces::raster_n32_premul((width, height)).ok_or(atoms::render_failed())?;
    surface.canvas().clear(Color::TRANSPARENT);
    Ok(surface)
}

fn batch_width(batch: Term) -> NifResult<i32> {
    if let Ok(term) = batch.map_get(atoms::width()) {
        if let Ok(width) = term.decode::<i32>() {
            return Ok(width);
        }
    }
    let (width, _, _) = batch.decode::<(i32, i32, Vec<Term>)>()?;
    Ok(width)
}

fn batch_height(batch: Term) -> NifResult<i32> {
    if let Ok(term) = batch.map_get(atoms::height()) {
        if let Ok(height) = term.decode::<i32>() {
            return Ok(height);
        }
    }
    let (_, height, _) = batch.decode::<(i32, i32, Vec<Term>)>()?;
    Ok(height)
}

fn command_from_compact<'a>(env: Env<'a>, command: Term<'a>) -> NifResult<Term<'a>> {
    let (op_id, args, opts) = command.decode::<(i64, Vec<Term>, Vec<(Atom, Term)>)>()?;
    map_new(env)
        .map_put(atoms::op(), compact_op_atom(op_id)?)?
        .map_put(atoms::args(), args)?
        .map_put(atoms::opts(), opts)
}

include!("generated_dispatch.rs");

fn draw_command_result(canvas: &skia_safe::Canvas, command: Term) -> NifResult<Result<(), Atom>> {
    match draw_command(canvas, command) {
        Ok(()) => Ok(Ok(())),
        Err(_) => Ok(Err(atoms::invalid_command())),
    }
}

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

    if let Ok(typeface_term) = term.map_get(atoms::typeface()) {
        let font_size = match term.map_get(atoms::size()) {
            Ok(size_term) => {
                if size_term.decode::<Atom>().is_ok_and(|atom| atom == atoms::nil()) {
                    size
                } else {
                    size_term.decode::<f64>()? as f32
                }
            }
            Err(_) => size,
        };

        if typeface_term.decode::<Atom>().is_ok_and(|atom| atom == atoms::nil()) {
            let typeface = FontMgr::new()
                .legacy_make_typeface(None, FontStyle::normal())
                .ok_or(rustler::Error::BadArg)?;
            return Ok(Font::new(typeface, font_size));
        }

        let typeface_ref = decode_encoded_font_ref(typeface_term)?;
        return Ok(Font::new(typeface_ref.typeface.clone(), font_size));
    }

    let typeface_ref = decode_encoded_font_ref(term)?;
    Ok(Font::new(typeface_ref.typeface.clone(), size))
}

rustler::init!("Elixir.Skia.Native");
