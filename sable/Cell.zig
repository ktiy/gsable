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

    pub fn atom(k: Kind) bool {
        return k != .array and k != .none;
    }
    pub fn promote(a: Kind, x: Kind) Kind {
        std.debug.assert(a.atom() and x.atom());
        if (a == .char or x == .char) return .char;
        if (a == .num or x == .num) return .num;
        return .byte;
    }
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

pub fn promote(a: Cell, x: Cell) Kind {
    return a.k.promote(x.k);
}

pub fn atom(self: Cell) bool {
    return self.k.atom();
}

pub fn empty(self: Cell) bool {
    return self.k == .none;
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

pub fn compare(x: Cell, y: Cell) std.math.Order {
    std.debug.assert(x.atom() and y.atom());

    const k = x.promote(y);
    return switch (k) {
        .num => |j| compare_num(
            x.coerce(j),
            y.coerce(j),
        ),
        .char => |j| std.math.order(
            x.coerce(j),
            y.coerce(j),
        ),
        .byte => |j| std.math.order(
            x.coerce(j),
            y.coerce(j),
        ),
        else => unreachable,
    };
}

fn compare_num(x: f64, y: f64) std.math.Order {
    const x_nan = std.math.isNan(x);
    const y_nan = std.math.isNan(y);
    if (x_nan and y_nan) return .eq;
    if (x_nan) return .gt;
    if (y_nan) return .lt;
    return std.math.order(x, y);
}

pub fn coerce(self: Cell, comptime k: Kind) To(k) {
    std.debug.assert(self.atom());

    return switch (k) {
        .num => switch (self.k) {
            .num => self.x.num,
            .byte => @floatFromInt(self.x.byte),
            .char => @floatFromInt(self.x.char),
            else => unreachable,
        },
        .char => switch (self.k) {
            .num => @intFromFloat(self.x.num),
            .byte => @as(u32, self.x.byte),
            .char => self.x.char,
            else => unreachable,
        },
        .byte => switch (self.k) {
            .num => @intFromFloat(self.x.num),
            .byte => self.x.byte,
            .char => @truncate(self.x.char),
            else => unreachable,
        },
        else => unreachable,
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
