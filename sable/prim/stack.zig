const std = @import("std");
const sbl = @import("sbl");

pub fn dup(m: *sbl.Machine) void {
    m.push(m.top().*);
}

pub fn drop(m: *sbl.Machine) void {
    _ = m.pop();
}

pub fn swap(m: *sbl.Machine) void {
    std.debug.assert(m.dat_p > 1);
    const dat_p = @as(usize, @intCast(m.dat_p));
    const dat_y = &m.dat[dat_p - 1];
    const dat_x = &m.dat[dat_p - 2];
    std.mem.swap(sbl.Cell, dat_x, dat_y);
}

pub fn over(m: *sbl.Machine) void {
    std.debug.assert(m.dat_p > 1);
    const dat_p = @as(usize, @intCast(m.dat_p));
    const dat_x = &m.dat[dat_p - 2];
    m.push(dat_x.*);
}

pub fn rot(m: *sbl.Machine) void {
    std.debug.assert(m.dat_p > 2);

    const dat_p = @as(usize, @intCast(m.dat_p));
    const dat_z = &m.dat[dat_p - 1];
    const dat_y = &m.dat[dat_p - 2];
    const dat_x = &m.dat[dat_p - 3];

    std.mem.swap(sbl.Cell, dat_x, dat_y);
    std.mem.swap(sbl.Cell, dat_y, dat_z);
}
