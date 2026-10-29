const Compiler = @This();

const std = @import("std");
const sbl = @import("sbl");

const Inst = sbl.Bytecode.Inst;
const Node = sbl.Syntax.Node;
const Span = sbl.SourceFile.Span;

const Env = std.ArrayList(?Def);

a: std.mem.Allocator,

buf: []const u8,
ast: sbl.Syntax,
ts: sbl.Token.Slice,
st: *sbl.SymTable,
sigs: []const sbl.StackEffect,
env: *Env,

lam_base: usize,
arr_base: usize,

fns: std.ArrayList(Code) = .empty,
arrs: std.ArrayList(sbl.Array) = .empty,
errs: std.ArrayList(sbl.CompileError) = .empty,

code: Code = .{},

pub const Code = struct {
    bc: std.ArrayList(Inst) = .empty,
    loc: std.ArrayList(Span) = .empty,

    fn deinit(self: *Code, gpa: std.mem.Allocator) void {
        self.bc.deinit(gpa);
        self.loc.deinit(gpa);
    }
};

pub const Def = struct {
    kind: sbl.Analysis.Binding,
    lam: usize,
};

pub const Error = std.mem.Allocator.Error;
const E = Error;

pub fn run(
    gpa: std.mem.Allocator,
    ast: sbl.Syntax,
    ts: sbl.Token.Slice,
    buf: []const u8,
    st: *sbl.SymTable,
    sema: sbl.Analysis.Result,
    env: *Env,
    lam_base: usize,
    arr_base: usize,
) E!sbl.Bytecode.Program {
    var w = Compiler{
        .a = gpa,
        .ast = ast,
        .ts = ts,
        .buf = buf,
        .st = st,
        .sigs = sema.sigs,
        .env = env,
        .lam_base = lam_base,
        .arr_base = arr_base,
    };
    defer w.deinit();

    const root = ast.tree.get(ast.root);
    for (ast.extra[root.lhs..root.rhs]) |stmt|
        try w.expr(stmt);
    try w.emit(.ret, root.token);

    if (w.errs.items.len > 0) {
        return .{
            .errors = try w.errs.toOwnedSlice(gpa),
        };
    }

    var bc: std.ArrayList(Inst) = .empty;
    var loc: std.ArrayList(Span) = .empty;
    var lambdas: std.ArrayList(usize) = .empty;

    try bc.appendSlice(gpa, w.code.bc.items);
    try loc.appendSlice(gpa, w.code.loc.items);

    for (w.fns.items) |f| {
        try lambdas.append(gpa, bc.items.len);
        try bc.appendSlice(gpa, f.bc.items);
        try loc.appendSlice(gpa, f.loc.items);
    }

    return .{
        .bc = try bc.toOwnedSlice(gpa),
        .loc = try loc.toOwnedSlice(gpa),
        .lambdas = try lambdas.toOwnedSlice(gpa),
        .errors = try w.errs.toOwnedSlice(gpa),
        .arrays = try w.arrays.toOwnedSlice(gpa),
    };
}

fn deinit(w: *Compiler) void {
    w.cur.deinit(w.gpa);
    for (w.fns.items) |*f| f.deinit(w.gpa);
    w.fns.deinit(w.gpa);
    for (w.arrays.items) |a| a.release(w.gpa);
    w.arrays.deinit(w.gpa);
    w.errs.deinit(w.gpa);
}

fn expr(w: *Compiler, n: Node.Index) E!void {
    switch (w.node(.kind, n)) {
        else => w.fail(.nyi, n),
    }
}

fn emit(w: *Compiler, inst: sbl.Bytecode.Inst, p: Span) !void {
    try w.code.bc.append(w.a, inst);
    try w.code.loc.append(w.a, p);
}

fn fail(w: *Compiler, k: sbl.CompileError.Kind, n: Node.Index) !void {
    const t: Span = w.ts.items(.pos)[w.node(.token, n)];
    const u: Span = w.ts.items(.pos)[w.node(.token_end, n)];
    try fail_p(k, Span.span(t.start, u.end));
}

fn fail_p(w: *Compiler, k: sbl.CompileError.Kind, p: Span) !void {
    try w.errs.append(w.a, .{ .kind = k, .pos = p });
}

fn span(w: *Compiler, tok: u32) Span {
    return w.tokens.items(.pos)[tok];
}

fn str(w: *Compiler, tok: u32) []const u8 {
    return w.span(tok).slice(w.buf);
}

fn node(w: *Compiler, comptime k: @EnumLiteral(), n: Node.Index) @TypeOf(w.ast.tree.items(k)[0]) {
    return w.ast.tree.items(k)[n];
}
