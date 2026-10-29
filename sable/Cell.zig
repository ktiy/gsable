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
    array: *Array.Header,
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

pub fn array(x: Array) Cell {
    return .{
        .k = .array,
        .x = .{ .array = x.header },
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
        .array => Array,
        .none => void,
    };
}

pub fn into(self: Cell, comptime k: Kind) To(k) {
    std.debug.assert(self.k == k);
    return switch (k) {
        .num => self.x.num,
        .byte => self.x.byte,
        .char => self.x.char,
        .array => Array{ .header = self.x.array },
        .none => {},
    };
}

pub fn format(self: Cell, w: *std.Io.Writer) !void {
    switch (self.k) {
        .num => try w.print("{d}", .{self.into(.num)}),
        .byte => try w.print("#{x}", .{self.into(.byte)}),
        .char => {
            const cp: u21 = @truncate(self.into(.char));
            var buf: [4]u8 = undefined;
            const len = std.unicode.utf8Encode(cp, &buf) catch {
                try w.print("(char #{X})", .{cp});
                return;
            };
            try w.writeAll(buf[0..len]);
        },
        .array => {
            try w.writeAll("[");
            var iter = self.into(.array).iter();
            //TODO: multidimensional arrays
            while (iter.next()) |v| {
                try w.print("{f} ", .{v});
            }
            try w.writeAll("\x08]");
        },
        .none => try w.print("(none)", .{}),
    }
}
