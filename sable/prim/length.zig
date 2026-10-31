const std = @import("std");
const sbl = @import("sbl");

pub fn run(m: *sbl.Machine) void {
    const x = m.pop();

    if (x.k == .none) {
        m.push(.num(0));
        return;
    }

    if (x.atom()) {
        m.push(.num(1));
        return;
    }

    const xs = x.into(.array);
    const len = xs.shape()[0];
    xs.release(m.gpa);

    m.push(.num(@floatFromInt(len)));
}
