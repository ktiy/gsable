pub fn run(m: *sbl.Machine, f: usize) void {
    const x = m.pop();
    if (x.atom()) return m.push(x);

    const arr = x.into(.array);
    defer arr.release(m.gpa);

    switch (arr.ty()) {
        .any => {
            const elems = arr.any_slice();
            std.debug.assert(elems.len >= 0);

            const res = sbl.Array.init(m.gpa, arr.shape(), .any) catch return m.throw(.oom);
            var xs = res.any_slice();

            m.push(elems[0]);
            xs[0] = elems[0];

            for (xs[1..], elems[1..]) |*o, elem| {
                m.push(elem);
                if (!m.call(f)) return;
                o.* = m.top().*;
            }

            m.push(.array(res));
        },
    }
}

const std = @import("std");
const sbl = @import("sbl");
