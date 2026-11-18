pub fn up(m: M) void {
    run(m, true);
}

pub fn down(m: M) void {
    run(m, false);
}

fn run(m: M, comptime ascend: bool) void {
    const x = m.pop();
    const y = order(m, x, ascend) catch |e| switch (e) {
        E.OutOfMemory => return m.throw(.oom),
        E.Nyi => return m.throw(.nyi),
        E.Rank => return m.throw(.rank),
    };
    m.push(y);
}

fn order(m: M, xc: T, comptime ascend: bool) E!T {
    if (xc.k != .array) return xc;

    const xs = xc.into(.array);
    if (xs.header.rank != 1) return E.Rank;

    var arr = try xs.prepare_write(m.gpa);
    const sort = comptime if (ascend) std.sort.asc else std.sort.desc;

    switch (xs.header.kind) {
        .any => {
            std.sort.pdq(T, arr.any_slice(), {}, struct {
                fn lt(_: void, a: T, b: T) bool {
                    return if (ascend)
                        a.compare(b) == .lt
                    else
                        a.compare(b) == .gt;
                }
            }.lt);
        },
        .num => std.sort.pdq(f64, arr.num_slice(), {}, comptime sort(f64)),
        .byte => std.sort.pdq(u8, arr.byte_slice(), {}, comptime sort(u8)),
        .char => std.sort.pdq(u32, arr.char_slice(), {}, comptime sort(u32)),
    }
    return .array(arr);
}

const std = @import("std");
const sbl = @import("sbl");
const M = *sbl.Machine;
const T = sbl.Cell;
const E = error{
    OutOfMemory,
    Nyi,
    Rank,
};
