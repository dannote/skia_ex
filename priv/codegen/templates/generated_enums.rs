#![allow(dead_code)]

use rustler::{Atom, NifResult};
use skia_safe::{paint, BlendMode, FilterMode, PathFillType};

use super::atoms;

__rq_entries!();
__rq_decoders!();
