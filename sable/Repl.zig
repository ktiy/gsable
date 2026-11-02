gpa: std.mem.Allocator,
r: Readline,
m: sbl.Machine,
bc: std.ArrayList(sbl.bc.Inst) = .empty,
loc: std.ArrayList(sbl.SourceFile.Span) = .empty,
lambdas: std.ArrayList(usize) = .empty,
arrays: std.ArrayList(sbl.Array) = .empty,
st: sbl.SymTable,
av: sbl.Analysis.Env = .empty,
cv: sbl.Compiler.Env = .empty,

const prefix = "sbl0.0$ ";

const help_index =
    \\?  help
    \\?k keymap
    \\?p primitives
;

const help_keymap =
    \\  ‿ `strand'
    \\[ ← `assign'
    \\f λ `function'
    \\i ι `iota'
    \\l ⧻ `length'
    \\o ⫦ `over'
    \\O ⊪ `rotate'
    \\p □ `peek'
    \\r △ `order up'
    \\R ▽ `order down'
    \\s ρ `shape'
    \\S Ρ `reshape'
    \\+ × `mul'
    \\- ÷ `div'
    \\1 ´ `fold'
;

const help_primitives =
    \\nyi
;

pub fn keymap(c: u8) ?u21 {
    return switch (c) {
        // syntax
        'f' => 'λ',
        '[' => '←',
        ' ' => '‿',
        // primitives
        'i' => 'ι',
        'l' => '⧻',
        'o' => '⫦',
        'O' => '⊪',
        'p' => '□',
        'r' => '△',
        'R' => '▽',
        's' => 'ρ',
        'S' => 'Ρ',
        '+' => '×',
        '-' => '÷',
        // modifiers
        '1' => '´',
        else => null,
    };
}

pub fn init(gpa: std.mem.Allocator) !Repl {
    return .{
        .gpa = gpa,
        .r = Readline{},
        .st = try sbl.SymTable.init(gpa),
        .m = sbl.Machine.init(gpa, .{
            .bc = &.{},
            .loc = &.{},
            .lambdas = &.{},
            .arrays = &.{},
            .errors = &.{},
        }),
    };
}

pub fn deinit(o: *Repl) void {
    o.m.deinit();
    for (o.arrays.items) |a| a.deinit(o.gpa);
    o.bc.deinit(o.gpa);
    o.loc.deinit(o.gpa);
    o.lambdas.deinit(o.gpa);
    o.arrays.deinit(o.gpa);
    o.st.deinit();
    o.av.deinit(o.gpa);
    o.cv.deinit(o.gpa);
}

pub fn run(self: *Repl) !void {
    while (true) {
        const line = self.r.read_line(prefix) catch |e| switch (e) {
            error.Eof => break,
            error.Interrupted => break,
            else => return e,
        };
        if (line.len > 0 and line[0] == '?') {
            self.help(line);
            continue;
        }

        try self.eval(line);
        self.r.write_bytes("\r\n");
    }
}

fn help(self: *Repl, str: []const u8) void {
    if (str.len <= 1) {
        self.r.write_bytes(help_index);
    } else switch (str[1]) {
        'k' => self.r.write_bytes(help_keymap),
        'p' => self.r.write_bytes(help_primitives),
        else => self.r.write_bytes(help_index),
    }
    self.r.write_bytes("\r\n\r\n");
}

fn eval(o: *Repl, str: [:0]const u8) !void {
    var lex = sbl.Token.Lexer.init(str, 0);
    var ts = lex.collect(o.gpa) catch {
        o.r.write_bytes("!lex\r\n");
        return;
    };
    defer ts.deinit(o.gpa);

    var ast = try sbl.Syntax.parse(o.gpa, ts);
    defer ast.deinit(o.gpa);
    if (ast.errors.len > 0) {
        o.r.write_bytes("!parse\r\n");
        return;
    }

    const sema = try sbl.Analysis.run_env(o.gpa, ast, ts, str, &o.st, &o.av);
    defer sema.deinit(o.gpa);
    if (sema.errors.len > 0) {
        for (sema.errors) |e| {
            o.r.write_bytes(@tagName(e.kind));
            o.r.write_bytes("\r\n");
        }
        o.r.write_bytes("!sema\r\n");
        return;
    }

    var prog = try sbl.Compiler.run(
        o.gpa,
        ast,
        ts,
        str,
        &o.st,
        sema,
        &o.cv,
        o.lambdas.items.len,
        o.arrays.items.len,
    );

    var cenv = try o.cv.clone(o.gpa);
    defer cenv.deinit(o.gpa);

    if (prog.errors.len > 0) {
        prog.deinit(o.gpa);
        o.cv.clearRetainingCapacity();
        try o.cv.appendSlice(o.gpa, cenv.items);
        o.r.write_bytes("!compile\r\n");
        return;
    }

    const start = o.bc.items.len;
    try o.bc.appendSlice(o.gpa, prog.bc);
    try o.loc.appendSlice(o.gpa, prog.loc);
    for (prog.lambdas) |i| try o.lambdas.append(o.gpa, start + i);
    try o.arrays.appendSlice(o.gpa, prog.arrays);

    o.gpa.free(prog.bc);
    o.gpa.free(prog.loc);
    o.gpa.free(prog.lambdas);
    o.gpa.free(prog.arrays);
    o.gpa.free(prog.errors);

    o.m.prog = .{
        .bc = o.bc.items,
        .loc = o.loc.items,
        .arrays = o.arrays.items,
        .lambdas = o.lambdas.items,
        .errors = &.{},
    };

    o.m.ip = start;
    o.m.dat_p = 0;
    o.m.ret_p = 0;
    o.m.e = .none;

    while (o.m.step()) {}

    if (o.m.e.kind != .none) {
        o.r.write_bytes("!");
        o.r.write_bytes(@tagName(o.m.e.kind));
        o.r.write_bytes("\r\n");
        return;
    }

    for (0..@intCast(o.m.dat_p)) |i| {
        const x = o.m.dat[i];
        const s = try std.fmt.allocPrint(o.gpa, "{f}\r\n", .{x});
        defer o.gpa.free(s);

        o.r.write_bytes(s);

        if (!x.atom()) x.into(.array).release(o.gpa);
    }

    o.m.dat_p = 0;
}

const Repl = @This();

const std = @import("std");
const sbl = @import("sbl");
const Readline = sbl.Readline;
