const std = @import("std");
const sbl = @import("sbl");

pub fn run(m: *sbl.Machine) void {
    const c = m.top();

    switch (c.k) {
        .num => {
            const len: isize = @intFromFloat(c.x.num);
            const arr = sbl.Array.init(m.gpa, &[_]sbl.Array.Dim{len}, .any) catch {
                return m.throw(.oom);
            };
            _ = m.pop();
            for (arr.any_slice(), 0..) |*v, i| {
                v.* = .num(@floatFromInt(i));
            }
            _ = m.push(.array(arr));
        },
        .array => m.throw(.nyi),
        else => m.throw(.type),
    }
}
