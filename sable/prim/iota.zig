const std = @import("std");
const sbl = @import("sbl");

pub fn run(m: *sbl.Machine) void {
    const c = m.top();

    switch (c.k) {
        .num => {
            const arr = array(m, @intFromFloat(c.x.num)) orelse return;
            _ = m.pop();
            for (arr.any_slice(), 0..) |*v, i| {
                v.* = .num(@floatFromInt(i));
            }
            m.push(.array(arr));
        },
        .byte => {
            const arr = array(m, @intCast(c.x.byte)) orelse return;
            _ = m.pop();
            for (arr.any_slice(), 0..) |*v, i| {
                if (i >= std.math.maxInt(u8)) unreachable;
                v.* = .byte(@intCast(i));
            }
            m.push(.array(arr));
        },
        .char => {
            const arr = array(m, @intCast(c.x.char)) orelse return;
            _ = m.pop();
            for (arr.any_slice(), 0..) |*v, i| {
                if (i >= std.math.maxInt(u32)) unreachable;
                v.* = .char(@intCast(i));
            }
            m.push(.array(arr));
        },
        .array => m.throw(.nyi),
        else => m.throw(.type),
    }
}

fn array(m: *sbl.Machine, len: isize) ?sbl.Array {
    return sbl.Array.init(m.gpa, &[_]sbl.Array.Dim{len}, .any) catch {
        m.throw(.oom);
        return null;
    };
}
