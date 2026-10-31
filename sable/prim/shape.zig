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

pub fn re(m: *sbl.Machine) void {
    m.throw(.nyi);
}
