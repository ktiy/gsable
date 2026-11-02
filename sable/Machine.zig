gpa: std.mem.Allocator,
prog: sbl.bc.Program,
dat: [dat_stack_size]Cell = undefined,
ret: [ret_stack_size]usize = undefined,
ip: usize = 0,
dat_p: Dat_P = 0,
ret_p: Ret_P = 0,
e: sbl.RuntimeError = .none,
mem: std.AutoHashMapUnmanaged(Symbol, Cell) = .empty,

pub fn init(gpa: std.mem.Allocator, p: sbl.bc.Program) Machine {
    return .{
        .gpa = gpa,
        .prog = p,
    };
}

pub fn deinit(m: *Machine) void {
    var it = m.mem.iterator();
    while (it.next()) |ent| {
        const val = ent.value_ptr;
        if (!val.atom()) val.into(.array).release(m.gpa);
    }
    m.mem.deinit(m.gpa);
}

pub fn throw(m: *Machine, e: sbl.RuntimeError.Kind) void {
    m.e = .{ .kind = e };
}

pub fn step(m: *Machine) bool {
    if (m.ip >= m.prog.bc.len) return false;
    const op = m.prog.bc[m.ip];
    const ip = m.ip;
    m.ip += 1;

    if (m.e.kind != .none) return false;
    switch (op) {
        .call_val => |cell| {
            m.push(cell);
        },
        .call_arr => |idx| {
            const x = m.prog.arrays[idx];
            x.retain();
            m.push(.array(x));
        },
        .call_sym => |sym| {
            const x = m.mem.get(sym).?;
            if (!x.atom()) x.into(.array).retain();
            m.push(x);
        },
        .call_prim => |tok| {
            const prim = sbl.primitives.run(tok);
            prim(m);
            return m.e.kind == .none;
        },
        .call_lam => |idx| {
            m.ret[@as(usize, @intCast(m.ret_p))] = ip;
            m.ret_p += 1;
            m.ip = m.prog.lambdas[idx];
        },
        .call_lam_mod => |x| {
            const idx, const tok = .{ x.lam, x.mod };
            const lam = m.prog.lambdas[idx];
            const mod = sbl.primitives.mod(tok);
            mod(m, lam);
            return m.e.kind == .none;
        },
        .pop_into_sym => |sym| {
            m.mem.put(m.gpa, sym, m.pop()) catch {
                m.throw(.oom);
                return false;
            };
        },
        .pop_into_arr => |num| {
            const arr = sbl.Array.init(m.gpa, &.{@intCast(num)}, .any) catch {
                m.throw(.oom);
                return false;
            };
            const slice = arr.any_slice();
            for (0..num) |j| {
                const i = num - 1 - j;
                slice[i] = m.pop();
            }

            m.push(.array(arr));
        },
        .ret => {
            if (m.ret_p <= 0) {
                return false;
            }
            m.ret_p -= 1;
            const ret = m.ret[@as(usize, @intCast(m.ret_p))];
            m.ip = ret;
        },
    }
    return true;
}

pub fn push(m: *Machine, x: Cell) void {
    std.debug.assert(m.dat_p < dat_stack_size);
    m.dat[@as(usize, @intCast(m.dat_p))] = x;
    m.dat_p += 1;
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

pub fn call(m: *Machine, f: usize) bool {
    if (m.ret_p >= ret_stack_size) {
        m.throw(.oom);
        return false;
    }

    const depth = m.ret_p;
    m.ret[@as(usize, @intCast(depth))] = m.ip;
    m.ret_p += 1;
    m.ip = f;

    while (m.ret_p > depth) {
        if (!m.step()) {
            if (m.e.kind == .none) {
                // ?
                m.throw(.nyi);
            }
            m.ret_p = depth;
            return false;
        }
    }

    return true;
}

const Machine = @This();

const dat_stack_size = 256;
const ret_stack_size = 256;
const Dat_P = std.math.IntFittingRange(-1, dat_stack_size);
const Ret_P = std.math.IntFittingRange(-1, ret_stack_size);

const std = @import("std");
const sbl = @import("sbl");
const Cell = sbl.Cell;
const Symbol = sbl.SymTable.Symbol;
