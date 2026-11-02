pub const Program = struct {
    bc: []const Inst = undefined,
    loc: []const Span = undefined,
    arrays: []const Array = undefined,
    lambdas: []const usize = undefined,
    errors: []const CompileError,

    pub fn deinit(self: *Program, gpa: std.mem.Allocator) void {
        if (self.errors.len > 0) {
            gpa.free(self.errors);
            return;
        }
        for (self.arrays) |a| a.deinit(gpa);
        gpa.free(self.bc);
        gpa.free(self.loc);
        gpa.free(self.arrays);
        gpa.free(self.lambdas);
        gpa.free(self.errors);
    }
};

pub const Inst = union(enum) {
    call_builtin: sbl.builtins.Builtin,
    call_val: Cell,
    call_arr: usize,
    call_sym: Symbol,
    call_prim: Token.Kind,
    call_lam: usize,
    call_lam_mod: struct { lam: u32, mod: Token.Kind },
    pop_into_sym: Symbol,
    pop_into_arr: u32,
    ret,

    pub fn format(self: Inst, w: *std.Io.Writer) !void {
        switch (self) {
            .call_builtin => |x| try w.print("CALL @{s}", .{@tagName(x)}),
            .call_val => |x| try w.print("PUSH {f}", .{x}),
            .call_arr => |x| try w.print("PUSH (array #{x})", .{x}),
            .call_sym => |x| try w.print("CALL (symbol #{x})", .{x}),
            .call_prim => |x| try w.print("CALL {}", .{x}),
            .call_lam => |x| try w.print("CALL (func #{x})", .{x}),
            .call_lam_mod => |x| try w.print("CALL {} (func #{x})", .{ x.mod, x.lam }),
            .pop_into_sym => |x| try w.print("-> (sym #{x})", .{x}),
            .pop_into_arr => |x| try w.print("[{d} ->]", .{x}),
            .ret => try w.print("RETURN", .{}),
        }
    }
};

pub const StackEffect = struct {
    in: usize,
    out: usize,

    pub fn init(in: usize, out: usize) StackEffect {
        return .{ .in = in, .out = out };
    }

    pub const nilad: StackEffect = .init(0, 1);
    pub const monad: StackEffect = .init(1, 1);
    pub const dyad: StackEffect = .init(2, 1);

    pub fn delta(self: StackEffect) isize {
        const in: isize = @intCast(self.in);
        const out: isize = @intCast(self.out);
        return out - in;
    }

    pub fn then(x: StackEffect, y: StackEffect) StackEffect {
        const xh = @min(x.out, y.in);
        const yn = y.in - xh;
        return .init(x.in + yn, x.out - xh + y.out);
    }
};

const std = @import("std");
const sbl = @import("sbl");
const Array = sbl.Array;
const Cell = sbl.Cell;
const CompileError = sbl.CompileError;
const Token = sbl.Token;
const Span = sbl.SourceFile.Span;
const Symbol = sbl.SymTable.Symbol;
