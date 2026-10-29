const std = @import("std");
const sbl = @import("sbl");
const M = *sbl.Machine;
const P = sbl.primitives.Prim;
const T = sbl.Cell;

pub const add = prim(Add);
pub const sub = prim(Sub);
pub const mul = prim(Mul);
pub const div = prim(Div);
pub const pow = prim(Pow);
pub const mod = prim(Mod);

pub fn prim(comptime F: type) P {
    return struct {
        pub fn run(m: M) void {
            const x = m.pop();
            const a = m.pop();
            const y = apply(F, m, a, x);
            _ = m.push(y);
        }
    }.run;
}

pub const Add = struct {
    pub fn ff(_: M, x: f64, y: f64) f64 {
        return x + y;
    }
    pub fn bb(_: M, x: u8, y: u8) u8 {
        return x +% y;
    }
    pub fn cc(_: M, x: u32, y: u32) u32 {
        return x +% y;
    }
};
pub const Sub = struct {
    pub fn ff(_: M, x: f64, y: f64) f64 {
        return x - y;
    }
    pub fn bb(_: M, x: u8, y: u8) u8 {
        return x -% y;
    }
    pub fn cc(_: M, x: u32, y: u32) u32 {
        return x -% y;
    }
};
pub const Mul = struct {
    pub fn ff(_: M, x: f64, y: f64) f64 {
        return x * y;
    }
    pub fn bb(_: M, x: u8, y: u8) u8 {
        return x *% y;
    }
    pub fn cc(_: M, x: u32, y: u32) u32 {
        return x *% y;
    }
};
pub const Div = struct {
    pub fn ff(_: M, x: f64, y: f64) f64 {
        return x / y;
    }
    pub fn bb(_: M, x: u8, y: u8) u8 {
        return @divFloor(x, y);
    }
    pub fn cc(_: M, x: u32, y: u32) u32 {
        return @divFloor(x, y);
    }
};
pub const Pow = struct {
    pub fn ff(_: M, x: f64, y: f64) f64 {
        return std.math.pow(f64, x, y);
    }
    pub fn bb(_: M, x: u8, y: u8) u8 {
        return std.math.pow(u8, x, y);
    }
    pub fn cc(_: M, x: u32, y: u32) u32 {
        return std.math.pow(u32, x, y);
    }
};
pub const Mod = struct {
    pub fn ff(_: M, x: f64, y: f64) f64 {
        return @rem(x, y);
    }
    pub fn bb(_: M, x: u8, y: u8) u8 {
        return x % y;
    }
    pub fn cc(_: M, x: u32, y: u32) u32 {
        return x % y;
    }
};

fn apply(comptime F: type, m: M, a: T, x: T) T {
    return apply_e(F, m, a, x) catch {
        m.throw(.oom);
        return a;
    };
}

fn apply_e(comptime F: type, m: M, a: T, x: T) !T {
    return if (a.empty() or x.empty())
        a
    else if (a.atom() and x.atom())
        apply_aa(F, m, a, x)
    else {
        m.throw(.nyi);
        return error.OutOfMemory;
    };
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
