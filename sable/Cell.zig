const Cell = @This();
const Array = @import("Array.zig");

const std = @import("std");
const builtin = @import("builtin");

k: Kind,
x: Data,

pub const Kind = enum(u8) {
    num,
    byte,
    char,
    array,
    none,
};

pub const Data = extern union {
    num: f64,
    byte: u8,
    char: u32,
    array: *Array,
};

pub fn num(x: f64) Cell {
    return .{
        .k = .num,
        .x = .{ .num = x },
    };
}

pub fn byte(x: u8) Cell {
    return .{
        .k = .byte,
        .x = .{ .byte = x },
    };
}

pub fn char(x: u32) Cell {
    return .{
        .k = .char,
        .x = .{ .char = x },
    };
}

pub fn array(x: *Array) Cell {
    return .{
        .k = .array,
        .x = .{ .array = x },
    };
}

pub fn none() Cell {
    return .{
        .k = .none,
        .x = undefined,
    };
}

pub fn atom(self: Cell) bool {
    return self.k != .array;
}

pub fn To(comptime k: Kind) type {
    return switch (k) {
        .num => f64,
        .byte => u8,
        .char => u32,
        .array => *Array,
        .none => void,
    };
}

pub fn into(self: Cell, comptime k: Kind) To(k) {
    std.debug.assert(self.k == k);
    return switch (k) {
        .num => self.x.num,
        .byte => self.x.byte,
        .char => self.x.char,
        .array => self.x.array,
        .none => {},
    };
}
