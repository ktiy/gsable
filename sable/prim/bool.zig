const prim = @import("pervasive.zig").prim2;

pub const eq = prim(Eq);
pub const neq = prim(Neq);
pub const gt = prim(Gt);
pub const gt_eq = prim(Gteq);
pub const lt = prim(Lt);
pub const lt_eq = prim(Lteq);

// zig fmt: off
const Eq   = struct { pub fn cmp(x: anytype, y: anytype) bool { return x == y; } };
const Neq  = struct { pub fn cmp(x: anytype, y: anytype) bool { return x != y; } };
const Gt   = struct { pub fn cmp(x: anytype, y: anytype) bool { return x > y; } };
const Gteq = struct { pub fn cmp(x: anytype, y: anytype) bool { return x >= y; } };
const Lt   = struct { pub fn cmp(x: anytype, y: anytype) bool { return x < y; } };
const Lteq = struct { pub fn cmp(x: anytype, y: anytype) bool { return x <= y; } };

const M = *sbl.Machine;
const std = @import("std");
const sbl = @import("sbl");
