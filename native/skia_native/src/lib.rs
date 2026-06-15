#![allow(deprecated)]

use rustler::{Atom, Binary, Encoder, Env, NifResult, OwnedBinary, ResourceArc, Term};
use skia_safe::{
    canvas::SaveLayerRec,
    image_filters, surfaces,
    textlayout::{FontCollection, ParagraphBuilder, ParagraphStyle, TextAlign, TextDirection, TextStyle},
    AlphaType, Color, ColorType, Data, EncodedImageFormat, FilterMode, Font, FontMgr, FontStyle,
    IPoint, Image, ImageInfo, Matrix, Paint, PaintStyle, PathBuilder, Point, RRect, Rect,
    SamplingOptions, Shader, TileMode,
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
include!("generated_path.rs");
include!("generated_paint.rs");

fn draw_save_impl(surface: &mut skia_safe::Surface) -> NifResult<()> {
    surface.canvas().save();
    Ok(())
}

fn draw_save_layer_impl<'a>(
    surface: &mut skia_safe::Surface,
    layer_opts: generated_opts::SaveLayerOpts<'a>,
    opts: &[(Atom, Term<'a>)],
) -> NifResult<()> {
    let bounds = match layer_opts.bounds {
        Some(term) => Some(rect_from_term(term)?),
        None => None,
    };
    let mut paint = Paint::default();
    paint.set_alpha((layer_opts.opacity.unwrap_or(1.0).clamp(0.0, 1.0) * 255.0).round() as u8);
    apply_blend_mode(&mut paint, opts)?;
    if let Some(sigma) = layer_opts.blur {
        if let Some(filter) = image_filters::blur((sigma, sigma), TileMode::Decal, None, None) {
            paint.set_image_filter(filter);
        }
    }

    let mut rec = SaveLayerRec::default().paint(&paint);
    if let Some(ref bounds) = bounds {
        rec = rec.bounds(bounds);
    }
    surface.canvas().save_layer(&rec);
    Ok(())
}

fn draw_restore_impl(surface: &mut skia_safe::Surface) -> NifResult<()> {
    surface.canvas().restore();
    Ok(())
}

fn draw_translate_impl<'a>(
    surface: &mut skia_safe::Surface,
    translate_opts: generated_opts::TranslateOpts<'a>,
    _opts: &[(Atom, Term<'a>)],
) -> NifResult<()> {
    surface
        .canvas()
        .translate((translate_opts.x, translate_opts.y));
    Ok(())
}

fn draw_rotate_impl<'a>(
    surface: &mut skia_safe::Surface,
    rotate_opts: generated_opts::RotateOpts<'a>,
    _opts: &[(Atom, Term<'a>)],
) -> NifResult<()> {
    surface.canvas().rotate(rotate_opts.degrees, None);
    Ok(())
}

fn draw_rotate_at_impl<'a>(
    surface: &mut skia_safe::Surface,
    rotate_opts: generated_opts::RotateAtOpts<'a>,
    _opts: &[(Atom, Term<'a>)],
) -> NifResult<()> {
    surface
        .canvas()
        .rotate(rotate_opts.degrees, Some(Point::new(rotate_opts.x, rotate_opts.y)));
    Ok(())
}

fn draw_scale_impl<'a>(
    surface: &mut skia_safe::Surface,
    scale_opts: generated_opts::ScaleOpts<'a>,
    _opts: &[(Atom, Term<'a>)],
) -> NifResult<()> {
    surface.canvas().scale((scale_opts.x, scale_opts.y));
    Ok(())
}

fn draw_concat_impl<'a>(
    surface: &mut skia_safe::Surface,
    concat_opts: generated_opts::ConcatOpts<'a>,
    _opts: &[(Atom, Term<'a>)],
) -> NifResult<()> {
    let matrix = matrix_from_term(concat_opts.matrix)?;
    surface.canvas().concat(&matrix);
    Ok(())
}

fn draw_clear_impl<'a>(surface: &mut skia_safe::Surface, args: Vec<Term<'a>>) -> NifResult<()> {

    if let Some(color) = args.first().and_then(|term| decode_color(*term).ok()) {
        surface.canvas().clear(color);
    }

    Ok(())
}

fn draw_rect_impl<'a>(
    surface: &mut skia_safe::Surface,
    rect_opts: generated_opts::RectOpts<'a>,
    opts: &[(Atom, Term<'a>)],
) -> NifResult<()> {
    let rect = Rect::from_xywh(rect_opts.x, rect_opts.y, rect_opts.width, rect_opts.height);
    draw_rect_shape(surface, rect, rect_opts.radius.unwrap_or(0.0), &opts)
}

fn draw_oval_impl<'a>(
    surface: &mut skia_safe::Surface,
    oval_opts: generated_opts::OvalOpts<'a>,
    opts: &[(Atom, Term<'a>)],
) -> NifResult<()> {
    let rect = Rect::from_xywh(oval_opts.x, oval_opts.y, oval_opts.width, oval_opts.height);

    if let Some(mut paint) = opt_fill_paint(opts, atoms::fill())? {
        apply_blend_mode(&mut paint, opts)?;
        surface.canvas().draw_oval(rect, &paint);
    }

    if let Some(color) = opt_color(opts, atoms::stroke())? {
        let paint = stroke_paint(color, oval_opts.stroke_width.unwrap_or(1.0), opts)?;
        surface.canvas().draw_oval(rect, &paint);
    }

    Ok(())
}

fn draw_arc_impl<'a>(
    surface: &mut skia_safe::Surface,
    arc_opts: generated_opts::ArcOpts<'a>,
    opts: &[(Atom, Term<'a>)],
) -> NifResult<()> {
    let rect = Rect::from_xywh(arc_opts.x, arc_opts.y, arc_opts.width, arc_opts.height);
    let use_center = arc_opts.use_center.unwrap_or(false);

    if let Some(mut paint) = opt_fill_paint(opts, atoms::fill())? {
        apply_blend_mode(&mut paint, opts)?;
        surface.canvas().draw_arc(
            rect,
            arc_opts.start_degrees,
            arc_opts.sweep_degrees,
            use_center,
            &paint,
        );
    }

    if let Some(color) = opt_color(opts, atoms::stroke())? {
        let paint = stroke_paint(color, arc_opts.stroke_width.unwrap_or(1.0), opts)?;
        surface.canvas().draw_arc(
            rect,
            arc_opts.start_degrees,
            arc_opts.sweep_degrees,
            use_center,
            &paint,
        );
    }

    Ok(())
}

fn draw_circle_impl<'a>(
    surface: &mut skia_safe::Surface,
    circle_opts: generated_opts::CircleOpts<'a>,
    opts: &[(Atom, Term<'a>)],
) -> NifResult<()> {
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

fn draw_line_impl<'a>(
    surface: &mut skia_safe::Surface,
    line_opts: generated_opts::LineOpts<'a>,
    opts: &[(Atom, Term<'a>)],
) -> NifResult<()> {
    let color = decode_color(line_opts.stroke)?;
    let paint = stroke_paint(color, line_opts.stroke_width.unwrap_or(1.0), &opts)?;

    surface.canvas().draw_line(
        point_from_term(line_opts.from)?,
        point_from_term(line_opts.to)?,
        &paint,
    );
    Ok(())
}

fn draw_text_impl<'a>(
    surface: &mut skia_safe::Surface,
    args: Vec<Term<'a>>,
    text_opts: generated_opts::TextOpts<'a>,
    _opts: &[(Atom, Term<'a>)],
) -> NifResult<()> {
    let text = args
        .first()
        .ok_or(rustler::Error::BadArg)?
        .decode::<String>()?;
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

    if let Some(width) = text_opts.width {
        draw_paragraph_text(surface, &text, text_opts.x, text_opts.y, width, size, &paint, &text_opts)?;
    } else {
        surface
            .canvas()
            .draw_str(text, (text_opts.x, text_opts.y), &font, &paint);
    }
    Ok(())
}

fn draw_paragraph_text<'a>(
    surface: &mut skia_safe::Surface,
    text: &str,
    x: f32,
    y: f32,
    width: f32,
    size: f32,
    paint: &Paint,
    text_opts: &generated_opts::TextOpts<'a>,
) -> NifResult<()> {
    let mut text_style = TextStyle::new();
    text_style.set_font_size(size);
    text_style.set_color(paint.color());

    let mut paragraph_style = ParagraphStyle::new();
    paragraph_style.set_text_style(&text_style);
    if let Some(align) = text_opts.align {
        paragraph_style.set_text_align(decode_text_align(align)?);
    }
    if let Some(direction) = text_opts.direction {
        paragraph_style.set_text_direction(decode_text_direction(direction)?);
    }

    let mut font_collection = FontCollection::new();
    font_collection.set_default_font_manager(FontMgr::default(), None);
    let mut paragraph_builder = ParagraphBuilder::new(&paragraph_style, font_collection);
    paragraph_builder.push_style(&text_style);
    paragraph_builder.add_text(text);
    let mut paragraph = paragraph_builder.build();
    paragraph.layout(width);
    paragraph.paint(surface.canvas(), Point::new(x, y));
    Ok(())
}

fn decode_text_align(value: Atom) -> NifResult<TextAlign> {
    if value == atoms::center() {
        Ok(TextAlign::Center)
    } else if value == atoms::right() {
        Ok(TextAlign::Right)
    } else if value == atoms::justify() {
        Ok(TextAlign::Justify)
    } else if value == atoms::left() {
        Ok(TextAlign::Left)
    } else {
        Err(rustler::Error::BadArg)
    }
}

fn decode_text_direction(value: Atom) -> NifResult<TextDirection> {
    if value == atoms::rtl() {
        Ok(TextDirection::RTL)
    } else if value == atoms::ltr() {
        Ok(TextDirection::LTR)
    } else {
        Err(rustler::Error::BadArg)
    }
}

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

fn clip_rect_impl<'a>(
    surface: &mut skia_safe::Surface,
    clip_opts: generated_opts::ClipRectOpts<'a>,
    _opts: &[(Atom, Term<'a>)],
) -> NifResult<()> {
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

fn clip_circle_impl<'a>(
    surface: &mut skia_safe::Surface,
    clip_opts: generated_opts::ClipCircleOpts<'a>,
    _opts: &[(Atom, Term<'a>)],
) -> NifResult<()> {
    let mut builder = PathBuilder::new();
    builder.add_circle(Point::new(clip_opts.x, clip_opts.y), clip_opts.radius, None);
    surface
        .canvas()
        .clip_path(&builder.detach(), None, clip_opts.antialias.unwrap_or(true));
    Ok(())
}

fn clip_path_impl<'a>(
    surface: &mut skia_safe::Surface,
    args: Vec<Term<'a>>,
    clip_opts: generated_opts::ClipPathOpts<'a>,
    opts: &[(Atom, Term<'a>)],
) -> NifResult<()> {
    let mut path = build_path(*args.first().ok_or(rustler::Error::BadArg)?)?;
    apply_fill_rule(&mut path, &opts)?;
    surface
        .canvas()
        .clip_path(&path, None, clip_opts.antialias.unwrap_or(true));
    Ok(())
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
        Some(term) => Ok(SamplingOptions::from(generated_enums::decode_sampling(
            term.decode::<Atom>()?,
        )?)),
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
