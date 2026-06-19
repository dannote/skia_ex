#![allow(dead_code)]

use rustler::{Atom, NifResult};
use skia_safe::{
    BlendMode, BlurStyle, ClipOp, EncodedImageFormat, FilterMode, MipmapMode, PaintCap,
    PaintJoin, PathFillType, PathOp, TileMode,
};

use super::atoms;

__rq_entries!();
__rq_decoders!();
