#![allow(dead_code)]

use rustler::{Atom, NifResult};
use skia_safe::{
    paint, BlendMode, BlurStyle, ClipOp, EncodedImageFormat, FilterMode, MipmapMode, PathFillType,
    PathOp, TileMode,
};

use super::atoms;

__rq_entries!();
__rq_decoders!();
