const Machine = @This();

const std = @import("std");
const Bytecode = @import("Bytecode.zig");
const Cell = @import("Cell.zig");
const CompiledProgram = Bytecode.Program;
const Error = @import("RuntimeError.zig");
const primitives = @import("primitives.zig");

const dat_stack_size = 256;
const ret_stack_size = 256;

const Dat_P = std.math.IntFittingRange(-1, dat_stack_size);
const Ret_P = std.math.IntFittingRange(-1, ret_stack_size);

prog: CompiledProgram,
dat: [dat_stack_size]Cell = undefined,
ret: [ret_stack_size]usize = undefined,

ip: usize = 0,
dat_p: Dat_P = 0,
ret_p: Ret_P = 0,

e: Error = .none,

pub fn init(p: CompiledProgram) Machine {
    return .{
        .prog = p,
    };
}

pub fn deinit(m: *Machine) void {
    _ = m;
}

pub fn throw(m: *Machine, e: Error.Kind) void {
    m.e = .{ .kind = e };
}

pub fn step(m: *Machine) bool {
    if (m.ip >= m.prog.bc.len) return false;
    const op = m.prog.bc[m.ip];
    m.ip += 1;

    if (m.e.kind != .none) return false;
    switch (op) {
        .call_val => |cell| {
            return m.push(cell);
        },
        .call_arr => |idx| {
            const x = m.prog.arrays[idx];
            x.retain();
            return m.push(.array(x));
        },
        .call_sym => |sym| {
            _ = sym;
            m.throw(.nyi);
            return false;
        },
        .call_prim => |tok| {
            const prim = primitives.run(tok);
            prim(m);
            return true;
        },
        .call_lam => |idx| {
            _ = idx;
            m.throw(.nyi);
            return false;
        },
        .pop_into_sym => |sym| {
            _ = sym;
            m.throw(.nyi);
            return false;
        },
        .pop_into_arr => |num| {
            _ = num;
            m.throw(.nyi);
            return false;
        },
        .ret => {
            if (m.ret_p != 0) m.throw(.nyi);
            return false;
        },
    }
}

pub fn push(m: *Machine, x: Cell) bool {
    std.debug.assert(m.dat_p < dat_stack_size);
    m.dat[@as(usize, @intCast(m.dat_p))] = x;
    m.dat_p += 1;
    return true;
}

pub fn top(m: *Machine) *Cell {
    std.debug.assert(m.dat_p > 0);
    const dat: usize = @intCast(m.dat_p);
    return &m.dat[dat - 1];
}

pub fn pop(m: *Machine) Cell {
    std.debug.assert(m.dat_p > 0);
    m.dat_p -= 1;
    return m.dat[@as(usize, @intCast(m.dat_p))];
}
