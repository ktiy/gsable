pub fn run(m: *sbl.Machine, f: usize) void {
    const x = m.pop();
    if (x.atom()) return m.push(x);

    const arr = x.into(.array);
    defer arr.release(m.gpa);

    switch (arr.ty()) {
        .any => {
            const elems = arr.any_slice();
            std.debug.assert(elems.len >= 0);

            m.push(elems[0]);
            for (elems[1..]) |elem| {
                m.push(elem);
                if (!m.call(f)) return;
            }
        },
    }
}

const std = @import("std");
const sbl = @import("sbl");
