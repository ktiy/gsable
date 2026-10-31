const std = @import("std");
const sbl = @import("sbl");
const Dim = sbl.Array.Dim;
const E = error{
    OutOfMemory,
};

pub fn run(m: *sbl.Machine) void {
    run_e(m) catch |e| switch (e) {
        E.OutOfMemory => m.throw(.oom),
    };
}

// a x -- a[x]
fn run_e(m: *sbl.Machine) !void {
    const x = m.pop();
    const a = m.top();

    if (x.k == .none) {
        if (!a.atom()) a.into(.array).release(m.gpa);
        a.* = x;
        return;
    }

    const as = a.into(.array);
    if (x.atom()) {
        if (as.header.rank != 1) {
            const sh = as.shape();

            // TODO: avoiding temporary allocation here?
            var start: []usize = try m.gpa.alloc(usize, sh.len);
            defer m.gpa.free(start);
            start[0] = x.coerce(.char);
            const start_idx = as.flat_index(start[0..sh.len]);

            var end: []usize = try m.gpa.alloc(usize, sh.len);
            defer m.gpa.free(end);
            end[0] = x.coerce(.char) + 1;
            const end_idx = as.flat_index(start[0..sh.len]);

            // TODO: array slice views without copying?
            var res = try sbl.Array.init(m.gpa, sh[1..], .any);
            var ai = as.iter();
            ai.pos = start_idx;

            for (res.any_slice()) |*elem| {
                const v = ai.next() orelse unreachable;
                elem.* = v;
            }

            _ = end_idx;

            as.release(m.gpa);
            a.* = .array(res);

            return;
        }

        var ai = as.iter();
        ai.pos = x.coerce(.char);

        a.* = ai.next() orelse return m.throw(.bounds);
        as.release(m.gpa);

        return;
    }

    // TODO: multi-dimensional indexes
    return m.throw(.nyi);
}
