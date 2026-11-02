kind: Kind,
i: SourceIndex = .none,

pub const SourceIndex = enum(usize) {
    none = std.math.maxInt(usize),
    _,
};

pub const T = error{Runtime};

pub const Kind = enum {
    none,
    nyi,
    oom,
    bounds,
    rank,
    shape,
    type,
};

pub const none = RuntimeError{ .kind = .none };

pub fn format(self: RuntimeError, w: *std.Io.Writer) !void {
    try w.print("!{s}", .{@tagName(self.kind)});
}

//TODO
pub fn report(self: RuntimeError, w: *std.Io.Writer, buf: []const u8) !void {
    try w.print("{f}", .{self});
    _ = buf;
    try w.writeByte('\n');
    try w.flush();
}

const RuntimeError = @This();
const std = @import("std");
