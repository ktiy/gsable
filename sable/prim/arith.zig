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

pub const add = prim(Add);
pub const sub = prim(Sub);
pub const mul = prim(Mul);
pub const div = prim(Div);
pub const pow = prim(Pow);
pub const mod = prim(Mod);

fn apply(comptime F: type, m: M, a: T, x: T) T {
    return apply_e(F, m, a, x) catch {
        m.throw(.oom);
        return a;
    };
}

fn apply_e(comptime F: type, m: M, a: T, x: T) !T {
    if (a.empty() or x.empty())
        return a;

    if (a.atom()) {
        return if (x.atom())
            apply_aa(F, m, a, x)
        else
            apply_aA(F, m, a, x);
    }

    if (x.atom())
        return apply_Aa(F, m, a, x);

    return apply_AA(F, m, a, x);
}

fn apply_aa(comptime F: type, m: M, a: T, x: T) T {
    const k = a.promote(x);
    return switch (k) {
        .num => |j| .num(F.ff(m, a.coerce(j), x.coerce(j))),
        .byte => |j| .byte(F.bb(m, a.coerce(j), x.coerce(j))),
        .char => |j| .char(F.cc(m, a.coerce(j), x.coerce(j))),
        else => unreachable,
    };
}

fn apply_aA(comptime F: type, m: M, a: T, xs: T) E!T {
    var arr = try xs.into(.array).prepare_write(m.gpa);

    switch (arr.header.kind) {
        .any => for (arr.any_slice()) |*elem| {
            const x = elem.*;
            elem.* = apply(F, m, a, x);
        },
    }

    return .array(arr);
}

fn apply_Aa(comptime F: type, m: M, as: T, x: T) E!T {
    var arr = try as.into(.array).prepare_write(m.gpa);

    switch (arr.header.kind) {
        .any => for (arr.any_slice()) |*elem| {
            const a = elem.*;
            elem.* = apply(F, m, a, x);
        },
    }

    return .array(arr);
}

fn apply_AA(comptime F: type, m: M, ac: T, xc: T) E!T {
    const as = ac.into(.array);
    const xs = xc.into(.array);

    // TODO: array broadcasting
    if (as.header.rank != xs.header.rank)
        return E.Rank;

    if (!std.mem.eql(i64, as.shape(), xs.shape()))
        return E.Shape;

    var arr = try as.prepare_write(m.gpa);
    var xi = xs.iter();

    switch (as.header.kind) {
        .any => for (arr.any_slice()) |*elem| {
            const x = xi.next().?;
            const a = elem.*;
            elem.* = apply(F, m, a, x);
        },
    }

    xs.release(m.gpa);

    return .array(arr);
}

fn prim(comptime F: type) P {
    return struct {
        pub fn run(m: M) void {
            const x = m.pop();
            const a = m.pop();
            const y = apply(F, m, a, x);
            m.push(y);
        }
    }.run;
}

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
    pub fn cc(_:M, x:C, y:C) C { return x % y; }
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
