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

            const x0 = elems[0];
            const p = m.dat_p;
            m.push(x0);
            if (!m.call(f)) return;
            const p2 = m.dat_p;

            // nilad
            if (p == p2) {
                for (elems[1..]) |elem| {
                    m.push(elem);
                    if (!m.call(f)) return;
                }
                return;
            }

            // monad
            const res = sbl.Array.init(m.gpa, arr.shape(), .any) catch return m.throw(.oom);
            const xs = res.any_slice();

            xs[0] = m.pop();

            for (xs[1..], elems[1..]) |*o, elem| {
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
