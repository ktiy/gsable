pub fn run(m: *sbl.Machine, f: usize) void {
    const x = m.pop();
    if (x.atom()) return m.push(x);

    const arr = x.into(.array);
    defer arr.release(m.gpa);

    // TODO
    std.debug.assert(arr.length() >= 0);

    const res = sbl.Array.init(m.gpa, arr.shape(), .any) catch return m.throw(.oom);
    var xs = res.any_slice();

    m.push(arr.get(0));
    xs[0] = arr.get(0);

    for (xs[1..], 1..) |*o, i| {
        m.push(arr.get(i));
        if (!m.call(f)) return;
        o.* = m.top().*;
    }

    m.push(.array(res));
}

const std = @import("std");
const sbl = @import("sbl");
