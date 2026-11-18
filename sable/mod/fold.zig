pub fn run(m: *sbl.Machine, f: usize) void {
    const x = m.pop();
    if (x.atom()) return m.push(x);

    const arr = x.into(.array);
    defer arr.release(m.gpa);

    // TODO: maybe runtime error instead lol
    std.debug.assert(arr.length() >= 0);

    m.push(arr.get(0));
    for (1..arr.length()) |i| {
        m.push(arr.get(i));
        if (!m.call(f)) return;
    }
}

const std = @import("std");
const sbl = @import("sbl");
