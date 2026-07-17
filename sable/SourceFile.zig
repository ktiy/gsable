const Self = @This();

path: []const u8,
content: [:0]const u8 = undefined,

pub const max_size = std.math.maxInt(u32);
pub const Span = struct {
    start: u32 = 0,
    end: u32 = 0,

    pub fn span(start: u32, end: u32) Span {
        return .{ .start = start, .end = end };
    }
};

var src_buffer: [4096]u8 = undefined;

pub fn read(src: *Self, io: std.Io, arena: std.mem.Allocator) !void {
    const cwd = std.Io.Dir.cwd();
    const file = try cwd.openFile(io, src.path, .{});
    var reader = file.reader(io, &src_buffer);

    const size = try reader.getSize();
    var content: [:0]u8 = try arena.allocSentinel(u8, size, 0);

    try reader.interface.readSliceAll(content);

    if (std.mem.startsWith(u8, content, "\xef\xbb\xbf")) content = content[3..];

    src.content = content;
}

const std = @import("std");
