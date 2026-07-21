const CompileError = @This();

kind: Kind,
pos: SourceFile.Span,

pub const Kind = enum {
    nyi,
    expected_array_close,
    expected_brace_close,
    expected_expression,
    dangling_strand,

    pub fn message(kind: Kind) []const u8 {
        return switch (kind) {
            .nyi => "nyi",
            .expected_array_close => "expected `]`",
            .expected_brace_close => "expected `}`",
            .expected_expression => "expected expression",
            .dangling_strand => "dangling strand",
        };
    }
};

pub fn report(
    err: CompileError,
    w: *std.Io.Writer,
    src: SourceFile,
) !void {
    const loc = err.pos.line_col(src.content);
    try w.print("{s}:{d}:{d}: error: {s}\n", .{
        src.path,
        loc.line,
        loc.column,
        err.kind.message(),
    });
    const slice = err.pos.slice(src.content);
    if (slice.len > 0) try w.print("  {s}\n", .{slice});
}

const SourceFile = @import("SourceFile.zig");
const std = @import("std");
