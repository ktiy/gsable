pub fn run(m: *sbl.Machine, f: usize) void {
    const x = m.pop();
    if (x.atom()) {
        m.push(x);
        _ = m.call(f);
        return;
    }

    const arr = x.into(.array);
    defer arr.release(m.gpa);

    switch (arr.ty()) {
        .any => {
            const elems = arr.any_slice();
            const res = sbl.Array.init(m.gpa, arr.shape(), .any) catch return m.throw(.oom);
            const xs = res.any_slice();

            for (xs, elems) |*o, elem| {
                m.push(elem);
                if (!m.call(f)) return;
                o.* = m.pop();
            }

            m.push(.array(res));
        },
    }
}

const sbl = @import("sbl");
const std = @import("std");
