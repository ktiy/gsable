pub fn prim2(comptime F: type) P {
    return struct {
        pub fn run(m: M) void {
            const x = m.pop();
            const a = m.pop();
            const y = apply(F, m, a, x);
            m.push(y);
        }
    }.run;
}

fn apply(comptime F: type, m: M, a: T, x: T) T {
    return apply_e(F, m, a, x) catch {
        m.throw(.oom);
        return a;
    };
}

fn apply_e(comptime F: type, m: M, a: T, x: T) E!T {
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

    if (comptime @hasDecl(F, "cmp")) {
        const r = switch (k) {
            .num => |j| F.cmp(a.coerce(j), x.coerce(j)),
            .byte => |j| F.cmp(a.coerce(j), x.coerce(j)),
            .char => |j| F.cmp(a.coerce(j), x.coerce(j)),
            else => unreachable,
        };
        return .num(if (r) 1 else 0);
    }

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

    const a_gt_x = as.ra() > xs.ra();
    const g = if (a_gt_x) as else xs;
    const l = if (a_gt_x) xs else as;
    const rs: usize = @intCast(l.ra());

    if (!std.mem.eql(i64, g.shape()[0..rs], l.shape()))
        return E.Shape;

    var rep: usize = 1;
    for (g.shape()[rs..]) |dim| {
        rep *= @intCast(dim);
    }

    var arr = try g.prepare_write(m.gpa);
    errdefer arr.release(m.gpa);
    const ls = l.any_slice();

    switch (as.header.kind) {
        .any => if (a_gt_x) {
            for (arr.any_slice(), 0..) |*elem, i| {
                const x = ls[i / rep];
                elem.* = try apply_e(F, m, elem.*, x);
            }
        } else {
            for (arr.any_slice(), 0..) |*elem, i| {
                const x = ls[i / rep];
                elem.* = try apply_e(F, m, x, elem.*);
            }
        },
    }

    l.release(m.gpa);
    return .array(arr);
}

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
