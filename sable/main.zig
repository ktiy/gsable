const std = @import("std");
const builtin = @import("builtin");
const build_options = @import("build_options");

pub const Token = @import("Token.zig");
pub const SourceFile = @import("SourceFile.zig");
pub const primitives = @import("primitives.zig");

const max_open_files = 256;

const usage: []const u8 =
    \\usage: sable [options] [input-file...]
    \\
    \\   -h, --help         Print this help message and exit.
    \\   -v, --version      Print the version number and exit.
    \\   -r, --repl         Run the sable repl.
    \\
;

const io = std.Io.Threaded.global_single_threaded.io();

var stdout_buf: [128]u8 = undefined;
var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buf);
const stdout = &stdout_writer.interface;

var stderr_buf: [128]u8 = undefined;
var stderr_writer = std.Io.File.stderr().writer(io, &stderr_buf);
const stderr = &stderr_writer.interface;

pub fn main(init: std.process.Init.Minimal) !void {
    var arena_state = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    var gpa_state = std.heap.DebugAllocator(.{}){};
    defer _ = gpa_state.deinit();
    const gpa = gpa_state.allocator();

    const args = try init.args.toSlice(arena);

    var repl: bool = false;
    var files_buf: [max_open_files]SourceFile = undefined;
    var files: std.ArrayList(SourceFile) = .initBuffer(&files_buf);

    for (args[1..]) |arg| {
        if (!std.mem.startsWith(u8, arg, "-")) {
            try files.appendBounded(.{ .path = arg });
        }
        else if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            try stdout.print("{s}", .{usage});
            try stdout.flush();
            std.process.exit(0);
        }
        else if (std.mem.eql(u8, arg, "-v") or std.mem.eql(u8, arg, "--version")) {
            try stderr.print("sable v{s}\n", .{build_options.version});
            try stderr.flush();
            std.process.exit(0);
        }
        else if (std.mem.eql(u8, arg, "-r") or std.mem.eql(u8, arg, "--repl")) {
            repl = true;
        }
        else {
            try stderr.print("sable: {s}: invalid option\n", .{arg});
            try stderr.print("{s}", .{usage});
            try stderr.flush();
            std.process.exit(1);
        }
    }

    if (files.items.len == 0 and !repl) {
        try stderr.print("sable: no input files provided\n", .{});
        try stderr.print("{s}", .{usage});
        try stderr.flush();
        std.process.exit(1);
    }

    for (files.items) |*src| {
        try src.read(io, gpa);
        std.log.debug("{s}:\n{s}", .{src.path, src.content});
    }
    defer for (files.items) |src| {
        gpa.free(src.content);
    };
}

test {
    std.testing.refAllDecls(@This());
}
