pub fn run(m: *sbl.Machine, f: usize) void {
    const x = m.pop();
    if (x.atom()) {
        m.push(x);
        _ = m.call(f);
        return;
    }

    const arr = x.into(.array);
    defer arr.release(m.gpa);

    run_e(m, f, arr) catch |e| switch (e) {
        error.Throw => {},
        error.OutOfMemory => m.throw(.oom),
        error.Shape => m.throw(.shape),
    };
}

const E = error{ Throw, Shape, OutOfMemory };

fn run_e(m: *sbl.Machine, f: usize, arr: sbl.Array) E!void {
    const gpa = m.gpa;
    const sh = arr.shape();
    const any = arr.any_slice();
    const n: usize = @intCast(sh[0]);

    if (n == 0) {
        arr.retain();
        return m.push(.array(arr));
    }

    const mc_sh = sh[1..];
    const mc_len = any.len / n;

    var row: ?sbl.Array = null;
    defer if (row) |r| r.release(gpa);

    var out: ?sbl.Array = null;
    errdefer if (out) |o| o.release(gpa);

    var sink = false;

    for (0..n) |i| {
        const chunk = any[i * mc_len ..][0..mc_len];

        var cell: sbl.Cell = undefined;
        if (mc_sh.len == 0) {
            retain(chunk[0]);
            cell = chunk[0];
        } else {
            const r = row orelse try sbl.Array.init(gpa, mc_sh, .any);
            for (r.any_slice(), chunk) |*d, s| {
                release(m, d.*);
                retain(s);
                d.* = s;
            }
            r.retain();
            row = r;
            cell = .array(r);
        }

        const p = m.dat_p;
        m.push(cell);
        if (!m.call(f)) return error.Throw;

        if (row) |r| {
            if (r.refc() != 1) {
                r.release(gpa);
                row = null;
            }
        }

        if (i == 0) sink = (m.dat_p == p);
        if (sink) continue;

        const y = m.pop();
        const ya: ?sbl.Array = if (y.atom()) null else y.into(.array);
        const ys: []const i64 = if (ya) |a| a.shape() else &.{};
        const yl: usize = if (ya) |a| @intCast(a.length()) else 1;

        if (i == 0) {
            var buf: [256]i64 = undefined;
            buf[0] = @intCast(n);
            @memcpy(buf[1..][0..ys.len], ys);
            out = try sbl.Array.init(gpa, buf[0 .. 1 + ys.len], .any);
        }

        const o = out.?;
        if (!std.mem.eql(i64, ys, o.shape()[1..])) {
            if (ya) |a| a.release(gpa);
            return error.Shape;
        }

        const dst = o.any_slice()[i * yl ..][0..yl];
        if (ya) |a| {
            @memcpy(dst, a.any_slice());
            if (a.refc() == 1) {
                a.deinit(gpa);
            } else {
                for (dst) |c| retain(c);
                a.release(gpa);
            }
        } else dst[0] = y;
    }

    if (!sink) m.push(.array(out.?));
}

fn retain(x: sbl.Cell) void {
    if (!x.atom()) x.into(.array).retain();
}

fn release(m: *sbl.Machine, x: sbl.Cell) void {
    if (!x.atom()) x.into(.array).release(m.gpa);
}

const sbl = @import("sbl");
const std = @import("std");
