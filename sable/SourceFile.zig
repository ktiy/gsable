const Self = @This();

path: []const u8,
content: []const u8 = undefined,

pub fn read(src: *Self, io: std.Io, gpa: std.mem.Allocator) !void {
    const cwd = std.Io.Dir.cwd();
    src.content = try cwd.readFileAlloc(io, src.path, gpa, .limited(std.math.maxInt(u32)));
}

const std = @import("std");
