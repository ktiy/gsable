const std = @import("std");
const builtin = @import("builtin");
const build_options = @import("build_options");

pub const Analysis = @import("Analysis.zig");
pub const Array = @import("Array.zig");
pub const ArrayIterator = @import("ArrayIterator.zig");
pub const Bytecode = @import("Bytecode.zig");
pub const Cell = @import("Cell.zig");
pub const Compiler = @import("Compiler.zig");
pub const CompileError = @import("CompileError.zig");
pub const Machine = @import("Machine.zig");
pub const Readline = @import("Readline.zig");
pub const Repl = @import("Repl.zig");
pub const RuntimeError = @import("RuntimeError.zig");
pub const SourceFile = @import("SourceFile.zig");
pub const SymTable = @import("SymbolTable.zig");
pub const Syntax = @import("Syntax.zig");
pub const Token = @import("Token.zig");
pub const primitives = @import("primitives.zig");

pub const max_open_files = 256;

const usage: []const u8 =
    \\usage: sable [options] [input-file...]
    \\
    \\   -h, --help         Print this help message and exit.
    \\   -v, --version      Print the version number and exit.
    \\   -r, --repl         Run the sable repl.
    \\   --verbose-ast      Dumps the parsed ast tree to stderr.
    \\   --verbose-bc       Dumps the compiled bytecode to stderr.
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

    var debug_ast: bool = false;
    var debug_bc: bool = false;

    for (args[1..]) |arg| {
        if (!std.mem.startsWith(u8, arg, "-")) {
            try files.appendBounded(.{ .path = arg });
        } else if (eq(arg, "-h") or eq(arg, "--help")) {
            try stdout.print("{s}", .{usage});
            try stdout.flush();
            std.process.exit(0);
        } else if (eq(arg, "-v") or eq(arg, "--version")) {
            try stderr.print("sable v{s}\n", .{build_options.version});
            try stderr.flush();
            std.process.exit(0);
        } else if (eq(arg, "-r") or eq(arg, "--repl")) {
            repl = true;
        } else if (eq(arg, "--verbose-ast")) {
            debug_ast = true;
        } else if (eq(arg, "--verbose-bc")) {
            debug_bc = true;
        } else {
            try stderr.print("sable: {s}: invalid option\n", .{arg});
            try stderr.print("{s}", .{usage});
            try stderr.flush();
            std.process.exit(1);
        }
    }

    if (repl) {
        var x = Repl.init();
        try x.run();
        std.process.exit(1);
    }

    if (files.items.len == 0 and !repl) {
        try stderr.print("sable: no input files provided\n", .{});
        try stderr.print("{s}", .{usage});
        try stderr.flush();
        std.process.exit(1);
    }

    for (files.items) |*src| {
        std.log.debug("reading {s}", .{src.path});
        try src.read(io, gpa);

        std.log.debug("lexing {s}", .{src.path});
        var lex = Token.Lexer.init(src.content, 0);
        var tokens = lex.collect(gpa) catch |e| {
            const loc = SourceFile.Position.cursor(src.content, lex.pos);
            std.log.err("{s}: {d}:{d}: {s}", .{
                src.path,
                loc.line,
                loc.column,
                @errorName(e),
            });
            std.process.exit(1);
        };
        defer tokens.deinit(gpa);

        std.log.debug("parsing {s}", .{src.path});
        var ast = try Syntax.parse(gpa, tokens);
        defer ast.deinit(gpa);
        try report_errors(src, ast.errors);

        if (debug_ast) {
            try ast.dump(stderr, tokens, src.content);
            try stdout.flush();
        }

        var st = try SymTable.init(gpa);
        defer st.deinit();

        std.log.debug("analysing {s}", .{src.path});
        const sema = try Analysis.run(
            gpa,
            ast,
            tokens,
            src.content,
            &st,
        );
        defer sema.deinit(gpa);
        try report_errors(src, sema.errors);

        var env: Compiler.Env = .empty;
        defer env.deinit(gpa);

        std.log.debug("compiling {s}", .{src.path});
        var prog = try Compiler.run(
            gpa,
            ast,
            tokens,
            src.content,
            &st,
            sema,
            &env,
            0,
            0,
        );
        defer prog.deinit(gpa);
        try report_errors(src, prog.errors);

        if (debug_bc) {
            for (prog.bc) |inst| {
                try stderr.print("{f}\n", .{inst});
            }
            try stderr.flush();
        }

        var m = Machine.init(prog);
        defer m.deinit();

        while (m.step()) {}

        if (m.e.kind != .none) {
            try m.e.report(stderr, src.content);
            std.process.exit(1);
        }

        if (m.dat_p > 1) {
            while (m.dat_p > 0) std.log.info("{d}: {f}", .{ m.dat_p, m.pop() });
        } else if (m.dat_p > 0) {
            while (m.dat_p > 0) std.log.info("{f}", .{m.pop()});
        }

        std.process.exit(0);
    }
    defer for (files.items) |src| {
        gpa.free(src.content);
    };
}

fn report_errors(src: *SourceFile, es: []const CompileError) !void {
    if (es.len > 0) {
        for (es) |e| try e.report(stderr, src.*);
        try stderr.flush();
        std.process.exit(1);
    }
}

fn eq(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

test {
    std.testing.refAllDecls(@This());
}
