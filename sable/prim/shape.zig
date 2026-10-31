const std = @import("std");
const sbl = @import("sbl");

pub fn run(m: *sbl.Machine) void {
    const xc = m.pop();
    if (xc.atom()) {
        _ = m.push(.none());
        return;
    }

    const xs = xc.into(.array);
    const sh = xs.shape();
    const ra = xs.header.rank;
    var arr = sbl.Array.init(m.gpa, &.{ra}, .any) catch {
        return m.throw(.oom);
    };

    for (sh[0..ra], 0..) |dim, i| {
        arr.any_slice()[i] = .num(@floatFromInt(dim));
    }
    xs.release(m.gpa);

    _ = m.push(.array(arr));
}

// a x -- a reshape x
pub fn re(m: *sbl.Machine) void {
    const a = m.pop();
    const x = m.pop();

    if (a.k == .none) {
        _ = m.push(a);
        return;
    }
    if (x.k == .none) return m.throw(.rank);

    if (x.atom()) {
        const u = x.coerce(.char);
        var arr = sbl.Array.init(m.gpa, &.{u}, .any) catch return m.throw(.oom);

        for (arr.any_slice()[0..u], 0..) |*elem, i|
            elem.* = get_wrap(a, i);

        _ = m.push(.array(arr));
        return;
    }

    const xs = x.into(.array);
    const ra = xs.header.rank;
    if (ra != 1) return m.throw(.rank);

    // TODO: can we avoid temporary allocation here ...
    const sh_len = xs.header.len;
    const sh = m.gpa.alloc(sbl.Array.Dim, sh_len) catch return m.throw(.oom);
    defer m.gpa.free(sh);

    var iter = xs.iter();
    for (sh) |*dim| {
        const elem = iter.next().?;
        dim.* = elem.coerce(.char);
    }

    var arr = sbl.Array.init(m.gpa, sh, .any) catch return m.throw(.oom);
    for (arr.any_slice(), 0..) |*elem, i| {
        elem.* = get_wrap(a, i);
    }

    _ = m.push(.array(arr));

    xs.release(m.gpa);
    if (!a.atom()) a.into(.array).release(m.gpa);
}

fn get_wrap(x: sbl.Cell, i: usize) sbl.Cell {
    if (x.atom()) return x;

    const arr = x.into(.array);
    const idx = i % arr.header.len;

    var iter = arr.iter();
    iter.pos = idx;
    return iter.next().?;
}
