pub fn prim2(comptime Op: type) Prim {
    return struct {
        pub fn run(m: MachinePtr) void {
            const x = m.pop();
            const a = m.pop();
            const y = apply(Op, m, a, x);
            m.push(y);
        }
    }.run;
}

pub fn arith(comptime F: type) Prim {
    return prim2(struct {
        pub fn out(comptime k: Cell.Kind) Cell.Kind {
            return k;
        }
        pub inline fn call(m: MachinePtr, comptime k: Cell.Kind, a: k.Into(), x: k.Into()) k.Into() {
            return switch (k) {
                .num => F.ff(m, a, x),
                .byte => F.bb(m, a, x),
                .char => F.cc(m, a, x),
                else => unreachable,
            };
        }
    });
}

pub fn cmp(comptime F: type) Prim {
    return prim2(struct {
        pub fn out(comptime _: Cell.Kind) Cell.Kind {
            return .num;
        }
        pub inline fn call(_: MachinePtr, comptime k: Cell.Kind, a: k.Into(), x: k.Into()) Cell.To(.num) {
            return if (F.cmp(a, x)) 1 else 0;
        }
    });
}

fn apply(comptime Op: type, m: MachinePtr, a: Cell, x: Cell) Cell {
    return apply_e(Op, m, a, x) catch {
        m.throw(.oom);
        return a;
    };
}

fn apply_e(comptime Op: type, m: MachinePtr, a: Cell, x: Cell) E!Cell {
    if (a.empty() or x.empty())
        return a;

    if (a.atom() and x.atom())
        return apply_aa(Op, m, a, x);

    return switch (kind_elem(a)) {
        inline .num, .byte, .char => |ak| switch (kind_elem(x)) {
            inline .num, .byte, .char => |xk| apply_homo(Op, m, a, ak, x, xk),
            else => apply_het(Op, m, a, x),
        },
        else => apply_het(Op, m, a, x),
    };
}

fn apply_aa(comptime Op: type, m: MachinePtr, a: Cell, x: Cell) Cell {
    return switch (a.promote(x)) {
        inline .num, .byte, .char => |k| from(
            Op.out(k),
            Op.call(m, k, a.coerce(k), x.coerce(k)),
        ),
        else => unreachable,
    };
}

fn apply_homo(
    comptime Op: type,
    m: MachinePtr,
    a: Cell,
    comptime ak: Cell.Kind,
    x: Cell,
    comptime xk: Cell.Kind,
) E!Cell {
    const k = comptime ak.promote(xk);
    const out_k = comptime Op.out(k);
    const out_arr_k = comptime @field(A.Kind, @tagName(k));
    const p = try plan(a, x);

    const in_place = p.gt.ty() == out_arr_k and p.gt.refc() == 1;
    const out = if (in_place) p.gt else try A.init(m.gpa, p.gt.shape(), out_arr_k);

    if (p.a_is_gt) {
        var atom_buf: [1]xk.Into() = undefined;
        const as = slice(ak, a.into(.array));
        const xs = elems(xk, x, &atom_buf);
        const out_s = slice(out_k, out);
        broadcast(Op, m, k, ak, xk, true, out_s, as, xs, p.rep);
    } else {
        var atom_buf: [1]ak.Into() = undefined;
        const as = elems(ak, a, &atom_buf);
        const xs = slice(xk, x.into(.array));
        const out_s = slice(out_k, out);
        broadcast(Op, m, k, xk, ak, false, out_s, xs, as, p.rep);
    }

    if (!in_place) p.gt.release(m.gpa);
    if (p.lt) |lt| lt.release(m.gpa);
    return .array(out);
}

fn slice(comptime k: Cell.Kind, arr: A) []k.Into() {
    return arr.payload().data(k.Into());
}

fn elems(comptime k: Cell.Kind, x: Cell, buf: *[1]k.Into()) []const k.Into() {
    if (x.is_array()) {
        return slice(k, x.into(.array));
    } else {
        buf[0] = x.into(k);
        return buf;
    }
}

fn apply_het(
    comptime Op: type,
    m: MachinePtr,
    a: Cell,
    x: Cell,
) E!Cell {
    const p = try plan(a, x);
    const atom = if (p.a_is_gt) x else a;

    const out = try A.init(m.gpa, p.gt.shape(), .any);
    errdefer out.release(m.gpa);

    for (out.any_slice(), 0..) |*elem, i| {
        const gt = p.gt.get(i);
        const lt = if (p.lt) |l| l.get(i / p.rep) else atom;
        const av, const xv = if (p.a_is_gt) .{ gt, lt } else .{ lt, gt };

        retain(av);
        retain(xv);

        elem.* = apply_e(Op, m, av, xv) catch |e| {
            release(m, av);
            release(m, xv);
            return e;
        };
    }

    p.gt.release(m.gpa);
    if (p.lt) |lt| lt.release(m.gpa);
    return .array(out);
}

fn broadcast(
    comptime Op: type,
    m: MachinePtr,
    comptime k: Cell.Kind,
    comptime gt_k: Cell.Kind,
    comptime lt_k: Cell.Kind,
    comptime gt_left: bool,
    xs: []Op.out(k).Into(),
    gts: []const gt_k.Into(),
    lts: []const lt_k.Into(),
    rep: usize,
) void {
    for (lts, 0..) |lt, j| {
        const l = lift(lt_k, k, lt);
        const i = j * rep;
        for (xs[i..][0..rep], gts[i..][0..rep]) |*elem, gt| {
            const g = lift(gt_k, k, gt);
            elem.* = if (gt_left) Op.call(m, k, g, l) else Op.call(m, k, l, g);
        }
    }
}

const Plan = struct {
    gt: A,
    lt: ?A,
    a_is_gt: bool,
    rep: usize,
};

fn plan(a: Cell, x: Cell) E!Plan {
    var a_is_gt: bool = undefined;
    var gt: A = undefined;
    var lt: ?A = undefined;

    if (a.atom()) {
        a_is_gt = false;
        gt = x.into(.array);
        lt = null;
    } else if (x.atom()) {
        a_is_gt = true;
        gt = a.into(.array);
        lt = null;
    } else {
        const aa, const xa = .{ a.into(.array), x.into(.array) };
        a_is_gt = aa.ra() > xa.ra();
        gt, lt = if (a_is_gt) .{ aa, xa } else .{ xa, aa };
    }

    const gt_sh = gt.shape();
    const lt_sh = if (lt) |p| p.shape() else &.{};
    const rs = lt_sh.len;

    if (rs > gt_sh.len or !std.mem.eql(i64, gt_sh[0..rs], lt_sh))
        return E.Shape;

    var rep: usize = 1;
    for (gt_sh[rs..]) |dim|
        rep *= @intCast(dim);

    return .{ .gt = gt, .lt = lt, .a_is_gt = a_is_gt, .rep = rep };
}

fn kind_elem(x: Cell) Cell.Kind {
    return switch (x.k) {
        .array => switch (x.into(.array).ty()) {
            .any => .array,
            .num => .num,
            .byte => .byte,
            .char => .char,
        },
        else => x.k,
    };
}

inline fn lift(comptime t: Cell.Kind, comptime u: Cell.Kind, x: t.Into()) u.Into() {
    if (comptime t == u) return x;
    return from(t, x).coerce(u);
}

fn retain(x: Cell) void {
    if (x.is_array()) {
        x.into(.array).retain();
    }
}

fn release(m: MachinePtr, x: Cell) void {
    if (x.is_array()) {
        x.into(.array).release(m.gpa);
    }
}

inline fn from(comptime k: Cell.Kind, x: k.Into()) Cell {
    return switch (k) {
        .num => .num(x),
        .byte => .byte(x),
        .char => .char(x),
        else => unreachable,
    };
}

const std = @import("std");
const sbl = @import("sbl");
const Cell = sbl.Cell;
const MachinePtr = *sbl.Machine;
const Prim = sbl.primitives.Prim;
const A = sbl.Array;
const E = error{
    OutOfMemory,
    Rank,
    Shape,
    NotYetImplemented,
};
