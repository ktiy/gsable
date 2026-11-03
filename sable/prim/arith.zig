const prim = @import("pervasive.zig").prim2;

pub const add = prim(Add);
pub const sub = prim(Sub);
pub const mul = prim(Mul);
pub const div = prim(Div);
pub const pow = prim(Pow);
pub const mod = prim(Mod);
pub const min = prim(Min);
pub const max = prim(Max);

// zig fmt: off
const N=f64; const B=u8; const C=u32;
const Add = struct {
    pub fn ff(_:M, x:N, y:N) N { return x + y; }
    pub fn bb(_:M, x:B, y:B) B { return x +% y; }
    pub fn cc(_:M, x:C, y:C) C { return x +% y; }
};
const Sub = struct {
    pub fn ff(_:M, x:N, y:N) N { return x - y; }
    pub fn bb(_:M, x:B, y:B) B { return x -% y; }
    pub fn cc(_:M, x:C, y:C) C { return x -% y; }
};
const Mul = struct {
    pub fn ff(_:M, x:N, y:N) N { return x * y; }
    pub fn bb(_:M, x:B, y:B) B { return x *% y; }
    pub fn cc(_:M, x:C, y:C) C { return x *% y; }
};
const Div = struct {
    pub fn ff(_:M, x:N, y:N) N { return x / y; }
    pub fn bb(_:M, x:B, y:B) B { return @divFloor(x,y); }
    pub fn cc(_:M, x:C, y:C) C { return @divFloor(x,y); }
};
const Pow = struct {
    pub fn ff(_:M, x:N, y:N) N { return std.math.pow(N,x,y); }
    pub fn bb(_:M, x:B, y:B) B { return std.math.pow(B,x,y); }
    pub fn cc(_:M, x:C, y:C) C { return std.math.pow(C,x,y); }
};
const Mod = struct {
    pub fn ff(_:M, x:N, y:N) N { return @rem(x,y); }
    pub fn bb(_:M, x:B, y:B) B { return x % y; }
    pub fn cc(_:M, x:C, y:C) C { return x % y; }
};
const Min = struct {
    pub fn ff(_:M, x:N, y:N) N { return @min(x,y); }
    pub fn bb(_:M, x:B, y:B) B { return @min(x,y); }
    pub fn cc(_:M, x:C, y:C) C { return @min(x,y); }
};
const Max = struct {
    pub fn ff(_:M, x:N, y:N) N { return @max(x,y); }
    pub fn bb(_:M, x:B, y:B) B { return @max(x,y); }
    pub fn cc(_:M, x:C, y:C) C { return @max(x,y); }
};

const std = @import("std");
const sbl = @import("sbl");
const M = *sbl.Machine;
const P = sbl.primitives.Prim;
const T = sbl.Cell;
const A = sbl.Array;
const E = error{
    OutOfMemory,
    Rank,
    Shape,
    NotYetImplemented,
};
