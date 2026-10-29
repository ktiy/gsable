//semantic analysis
const Analysis = @This();
const std = @import("std");
const sbl = @import("sbl");
const CompileError = sbl.CompileError;
const Node = Syntax.Node;
const Syntax = sbl.Syntax;
const Token = sbl.Token;
const Bytecode = sbl.Bytecode;
const StackEffect = sbl.Bytecode.StackEffect;
const SymTable = sbl.SymTable;
const Symbol = sbl.SymTable.Symbol;
const E = Error;
const Self = Analysis;

pub const Error = std.mem.Allocator.Error;

gpa: std.mem.Allocator,
ast: Syntax,
ts: Token.Slice,
buf: []const u8,
st: *SymTable,
errors: std.ArrayList(CompileError) = .empty,
/// Node.Index idx
sigs: []StackEffect,
/// Symbol idx
env: std.ArrayList(?StackEffect) = .empty,

pub const Result = struct {
    sigs: []StackEffect,
    errors: []CompileError,

    pub fn deinit(x: Result, a: std.mem.Allocator) void {
        a.free(x.sigs);
        a.free(x.errors);
    }
};

pub fn run(
    gpa: std.mem.Allocator,
    ast: Syntax,
    ts: Token.Slice,
    buf: []const u8,
    st: *SymTable,
) E!Result {
    const sigs = try gpa.alloc(StackEffect, ast.tree.len);
    errdefer gpa.free(sigs);
    @memset(sigs, StackEffect.init(0, 0));

    var x: Self = .{
        .gpa = gpa,
        .ast = ast,
        .ts = ts,
        .buf = buf,
        .st = st,
        .sigs = sigs,
    };
    defer x.env.deinit(gpa);
    errdefer x.errors.deinit(gpa);

    const root = ast.tree.get(ast.root);
    var acc = StackEffect.init(0, 0);
    for (ast.extra[root.lhs..root.rhs]) |stmt| {
        const next = acc.then(try x.resolve(stmt));
        if (next.in > acc.in) {
            try x.err(.stack_underflow, ast.tree.items(.token)[stmt]);
        }
        acc = next;
    }
    sigs[ast.root] = acc;

    return .{
        .sigs = sigs,
        .errors = try x.errors.toOwnedSlice(gpa),
    };
}

pub const Binding = enum {
    value,
    function,
    none,
};

pub fn classify(e: StackEffect) Binding {
    if (e.in > 0) return .function;
    if (e.out == 1) return .value;
    return .none;
}

fn resolve(x: *Self, idx: Node.Index) E!StackEffect {
    const node = x.ast.tree.get(idx);
    const eff: StackEffect = switch (node.kind) {
        .real, .byte, .string => StackEffect.nilad,
        .primitive => try x.primitive(node),
        .builtin => blk: {
            try x.err(.nyi, node.token);
            break :blk StackEffect.nilad;
        },
        .symbol => try x.use_symbol(node),
        .assign => try x.assign(node),
        .modify => try x.modify(node),
        .sequence => try x.compose(node.lhs, node.rhs),
        .array => try x.array(node),
        .modifier => unreachable,
    };
    x.sigs[idx] = eff;
    return eff;
}

fn compose(x: *Self, start: u32, end: u32) E!StackEffect {
    var acc = StackEffect.init(0, 0);
    for (x.ast.extra[start..end]) |child| {
        acc = acc.then(try x.resolve(child));
    }
    return acc;
}

fn primitive(x: *Self, node: Node) E!StackEffect {
    const kind = x.ts.items(.kind)[node.token];
    return primitive_effect(kind) orelse blk: {
        try x.err(.nyi, node.token);
        break :blk StackEffect.nilad;
    };
}

fn use_symbol(x: *Self, node: Node) E!StackEffect {
    const sym = try x.intern(node.token);
    if (x.lookup(sym)) |e| return e;

    try x.err(.unbound_symbol, node.token);
    return StackEffect.nilad;
}

/// lhs: symbol node, rhs: expression node
fn assign(x: *Self, node: Node) E!StackEffect {
    const eff = try x.resolve(node.rhs);
    const sym = try x.intern(x.ast.tree.items(.token)[node.lhs]);
    std.debug.assert(sym != .none);

    if (classify(eff) != .none) {
        try x.bind(sym, eff);
    } else {
        try x.err(.invalid_binding, node.token);
        try x.bind(sym, StackEffect.nilad);
    }
    return StackEffect.init(0, 0);
}

/// lhs: function node, rhs: modifier node
fn modify(x: *Self, node: Node) E!StackEffect {
    const operand = try x.resolve(node.lhs);
    const mod_tok = x.ast.tree.items(.token)[node.rhs];

    switch (x.ts.items(.kind)[mod_tok]) {
        .fold => { // : dyad -> monad
            if (operand.in != 2 or operand.out != 1) {
                try x.err(.bad_modifier_operand, mod_tok);
            }
            return StackEffect.monad;
        },
        else => {
            try x.err(.nyi, mod_tok);
            return operand;
        },
    }
}

fn array(x: *Self, node: Node) E!StackEffect {
    for (x.ast.extra[node.lhs..node.rhs]) |child| {
        const e = try x.resolve(child);
        if (e.in != 0 or e.out != 1) {
            try x.err(.bad_strand_element, x.ast.tree.items(.token)[child]);
        }
    }
    return StackEffect.nilad;
}

fn primitive_effect(kind: Token.Kind) ?StackEffect {
    return switch (kind) {
        .dup => StackEffect.init(1, 2),
        .drop => StackEffect.init(1, 0),
        .swap => StackEffect.init(2, 2),
        .over => StackEffect.init(2, 3),
        .rot => StackEffect.init(3, 3),
        .iota, .shape, .length, .order_up, .order_down => StackEffect.monad,
        .peek, .reshape, .add, .sub, .mul, .div, .pow, .mod => StackEffect.dyad,
        else => null,
    };
}

fn intern(x: *Self, t: Token.Index) E!Symbol {
    return x.st.intern(x.ts.items(.pos)[t].slice(x.buf));
}

fn lookup(x: *Self, sym: Symbol) ?StackEffect {
    const i: usize = @intFromEnum(sym);
    if (i >= x.env.items.len) return null;
    return x.env.items[i];
}

fn bind(x: *Self, sym: Symbol, e: StackEffect) E!void {
    const i: usize = @intFromEnum(sym);
    if (i >= x.env.items.len) {
        try x.env.appendNTimes(x.gpa, null, i + 1 - x.env.items.len);
    }
    x.env.items[i] = e;
}

fn err(x: *Self, k: CompileError.Kind, t: Token.Index) E!void {
    try x.errors.append(x.gpa, .{
        .kind = k,
        .pos = x.ts.items(.pos)[t],
    });
}

fn check(src: [:0]const u8, expected: StackEffect, expected_errs: usize) !void {
    const gpa = std.testing.allocator;

    var lex = Token.Lexer.init(src, 0);
    var ts = try lex.collect(gpa);
    defer ts.deinit(gpa);

    var ast = try Syntax.parse(gpa, ts);
    defer ast.deinit(gpa);

    try std.testing.expectEqual(0, ast.errors.len);

    var st = try SymTable.init(gpa);
    defer st.deinit();

    const res = try run(gpa, ast, ts, src, &st);
    defer res.deinit(gpa);

    try std.testing.expectEqual(expected_errs, res.errors.len);
    const got = res.sigs[ast.root];
    try std.testing.expectEqual(expected.in, got.in);
    try std.testing.expectEqual(expected.out, got.out);
}

test "classify" {
    try std.testing.expectEqual(Binding.value, classify(StackEffect.nilad));
    try std.testing.expectEqual(Binding.function, classify(StackEffect.dyad));
    try std.testing.expectEqual(Binding.none, classify(StackEffect.init(0, 0)));
    try std.testing.expectEqual(Binding.none, classify(StackEffect.init(0, 2)));
}

test "literals and primitives" {
    try check("1 2 +", StackEffect.nilad, 0);
}

test "stack underflow" {
    try check("1 +", StackEffect.init(1, 1), 1);
}

test "unbound symbol" {
    try check("x", StackEffect.nilad, 1);
}

test "evaluate nilad value binding" {
    try check("x ← 1 2 +\nx x +", StackEffect.nilad, 0);
}

test "binding to multiple values" {
    try check("f ← 1 2", StackEffect.init(0, 0), 1);
}

test "sanity nilad" {
    try check("avg ← .+´~⧻÷\n10‿20‿30‿40 avg", StackEffect.nilad, 0);
}
