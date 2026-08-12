const Bytecode = @This();

const std = @import("std");
const Array = @import("Array.zig");
const Token = @import("Token.zig");
const Cell = @import("Cell.zig");
const CompileError = @import("CompileError.zig");
const SourceFile = @import("SourceFile.zig");
const SymbolTable = @import("SymbolTable.zig");
const Symbol = SymbolTable.Symbol;

pub const Program = struct {
    bc: []const Inst = undefined,
    loc: []const SourceFile.Span = undefined,
    arrays: []const Array = undefined,
    lambdas: []const usize = undefined,
    errors: []const CompileError,
};

pub const Inst = union(enum) {
    call_val: Cell,
    call_arr: usize,
    call_sym: Symbol,
    call_prim: Token,
    call_lam: usize,
    pop_into_sym: Symbol,
    ret,

    pub fn format(self: Inst, w: *std.Io.Writer) !void {
        switch (self) {
            .call_val => |x| try w.print("PUSH {d}", .{x}),
            .call_arr => |x| try w.print("PUSH ARRAY {d}", .{x}),
            .call_sym => |x| try w.print("PUSH SYMBOL {d}", .{x}),
            .call_prim => |x| try w.print("CALL PRIM {}", .{x}),
            .call_lam => |x| try w.print("CALL FUNCTION @ {d}", .{x}),
            .pop_into_sym => |x| try w.print("POP INTO SYMBOL {d}", .{x}),
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
};
