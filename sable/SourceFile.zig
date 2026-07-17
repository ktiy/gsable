const Self = @This();

path: []const u8,
content: [:0]const u8 = undefined,

pub const max_size = std.math.maxInt(u32);

var src_buffer: [4096]u8 = undefined;

pub fn read(src: *Self, io: std.Io, arena: std.mem.Allocator) !void {
    std.log.debug("reading {s}", .{src.path});

    const cwd = std.Io.Dir.cwd();
    const file = try cwd.openFile(io, src.path, .{});
    var reader = file.reader(io, &src_buffer);

    const size = try reader.getSize();
    var content: [:0]u8 = try arena.allocSentinel(u8, size, 0);

    try reader.interface.readSliceAll(content);

    if (std.mem.startsWith(u8, content, "\xef\xbb\xbf")) content = content[3..];

    src.content = content;
}

pub const Span = struct {
    start: u32 = 0,
    end: u32 = 0,

    pub fn span(start: u32, end: u32) Span {
        return .{ .start = start, .end = end };
    }

    pub fn slice(self: Span, buf: []const u8) []const u8 {
        return buf[self.start..self.end];
    }

    pub fn line_col(self: Span, buf: []const u8) Position {
        return Position.cursor(buf, self.start, self.end);
    }
};

pub const Position = struct {
    line: u32 = 1,
    column: u32 = 1,
    line_1: u32 = 1,
    column_1: u32 = 1,

    pub fn cursor(buf: []const u8, idx_0: u32, idx_1: u32) Position {
        std.debug.assert(idx_0 < idx_1);
        std.debug.assert(idx_1 <= buf.len);

        var pos = Position{};

        var i: u32 = 0;
        while (i < idx_0) {
            const len, const cp = decode(buf[i..]);
            i += len;
            pos.column += 1;
            if (cp == '\n') {
                pos.line += 1;
                pos.column = 1;
            }
        }

        pos.line_1 = pos.line;
        pos.column_1 = pos.column;
        while (i < idx_1) {
            const len, const cp = decode(buf[i..]);
            i += len;
            pos.column_1 += 1;
            if (cp == '\n') {
                pos.line_1 += 1;
                pos.column_1 = 1;
            }
        }

        return pos;
    }
};

fn decode(buf: []const u8) struct { u3, u21 } {
    const len = std.unicode.utf8ByteSequenceLength(buf[0]) catch unreachable;
    const cp = std.unicode.utf8Decode(buf[0..len]) catch unreachable;
    return .{ len, cp };
}

const std = @import("std");
