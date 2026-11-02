gpa: std.mem.Allocator,

buf: []const u8,
ast: sbl.Syntax,
ts: sbl.Token.Slice,
st: *sbl.SymTable,
sigs: []const StackEffect,
env: *Env,

lam_base: usize,
arr_base: usize,

fns: std.ArrayList(Code) = .empty,
arrs: std.ArrayList(sbl.Array) = .empty,
errs: std.ArrayList(sbl.CompileError) = .empty,

code: Code = .{},

pub const Env = std.ArrayList(?Def);

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
) E!sbl.bc.Program {
    var w = Compiler{
        .gpa = gpa,
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

    try w.arrs.ensureTotalCapacity(gpa, 16);

    const root = ast.tree.get(ast.root);
    for (ast.extra[root.lhs..root.rhs]) |stmt| {
        try w.expr(stmt);
    }
    try w.emit_p(.ret, w.span(root.token));

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
        .arrays = try w.arrs.toOwnedSlice(gpa),
    };
}

fn deinit(w: *Compiler) void {
    w.code.deinit(w.gpa);
    for (w.fns.items) |*f| f.deinit(w.gpa);
    w.fns.deinit(w.gpa);
}

fn expr(w: *Compiler, n: Node.Index) E!void {
    switch (w.node(.kind, n)) {
        inline .real, .byte, .string => |k| try w.push_const(k, n),

        .array => |k| {
            if (w.is_const(k, n)) {
                return w.push_const(k, n);
            }

            const lhs = w.node(.lhs, n);
            const rhs = w.node(.rhs, n);
            const len = rhs - lhs;
            for (w.ast.extra[lhs..rhs]) |m| {
                try w.expr(m);
            }
            try w.emit(.{ .pop_into_arr = len }, n);
        },

        .primitive => {
            const t = w.node(.token, n);
            try w.emit(.{ .call_prim = w.kind(t) }, n);
        },

        .symbol => {
            const t = w.node(.token, n);
            const sym = try w.st.intern(w.str(t));
            const def = w.lookup(sym) orelse {
                try w.fail(.unbound_symbol, n);
                return;
            };
            switch (def.kind) {
                .value => try w.emit(.{ .call_sym = sym }, n),
                .function => try w.emit(.{ .call_lam = def.lam }, n),
                .none => unreachable,
            }
        },

        .assign => {
            const lhs = w.node(.lhs, n);
            const rhs = w.node(.rhs, n);
            const lhs_tok = w.node(.token, lhs);
            const sym = try w.intern(w.str(lhs_tok));
            switch (sbl.Analysis.classify(w.sigs[rhs])) {
                .value => {
                    try w.expr(rhs);
                    try w.emit(.{ .pop_into_sym = sym }, rhs);
                    try w.bind(sym, .{ .kind = .value, .lam = 0 });
                },
                .function => {
                    const lam = try w.lambda(rhs);
                    // TODO: runtime value ?
                    try w.bind(sym, .{ .kind = .function, .lam = lam });
                },
                .none => unreachable,
            }
        },

        .modifier => unreachable,
        .modify => {
            const lhs = w.node(.lhs, n);
            const rhs = w.node(.rhs, n);

            // TODO: inlining primitives etc
            const lam = try w.lambda(lhs);
            const mod_idx = w.node(.token, rhs);
            const mod = w.ts.items(.kind)[mod_idx];

            std.debug.assert(lam <= std.math.maxInt(u32));
            try w.emit(.{ .call_lam_mod = .{
                .lam = @intCast(lam),
                .mod = mod,
            } }, lhs);
        },

        .sequence => {
            const lhs = w.node(.lhs, n);
            const rhs = w.node(.rhs, n);
            for (w.ast.extra[lhs..rhs]) |m| try w.expr(m);
        },

        .builtin => try w.fail(.nyi, n),
    }
}

fn is_const(w: *Compiler, comptime k: Node.Kind, n: Node.Index) bool {
    return switch (k) {
        .real, .byte, .string => true,
        .array => {
            const lhs = w.node(.lhs, n);
            const rhs = w.node(.rhs, n);
            for (w.ast.extra[lhs..rhs]) |m| {
                const m_is_const = switch (w.node(.kind, m)) {
                    inline else => |j| w.is_const(j, m),
                };
                if (!m_is_const) return false;
            }
            return true;
        },
        else => false,
    };
}

fn push_const(w: *Compiler, comptime k: Node.Kind, n: Node.Index) E!void {
    const cell = (try w.node_to_cell(k, n)) orelse return;
    if (cell.atom()) {
        try w.emit(.{ .call_val = cell }, n);
        return;
    }

    const arr = cell.into(.array);
    errdefer arr.release(w.gpa);

    const i = w.arrs.items.len;
    try w.arrs.append(w.gpa, arr);
    try w.emit(.{ .call_arr = w.arr_base + i }, n);
}

fn node_to_cell(w: *Compiler, comptime k: Node.Kind, n: Node.Index) E!?Cell {
    var o: [512]u8 = undefined;
    const t = w.node(.token, n);
    const u = w.str(w.node(.token, n));

    switch (k) {
        //TODO: more detailed error reporting
        .real => {
            const s = strip_num(&o, u) orelse return w.invalid(t);
            const x = std.fmt.parseFloat(f64, s) catch return w.invalid(t);
            return Cell.num(x);
        },
        .byte => {
            const s = strip_num(&o, u[1..]) orelse return w.invalid(t);
            const x = std.fmt.parseUnsigned(u8, s, 16) catch return w.invalid(t);
            return Cell.byte(x);
        },
        .array => {
            const lhs = w.node(.lhs, n);
            const rhs = w.node(.rhs, n);
            const ns = w.ast.extra[lhs..rhs];
            const sh = [_]sbl.Array.Dim{@intCast(ns.len)};
            const arr = try sbl.Array.init(w.gpa, &sh, .any);
            errdefer arr.release(w.gpa);

            for (ns, arr.any_slice()) |m, *v| {
                const cell = switch (w.node(.kind, m)) {
                    inline else => |j| try w.node_to_cell(j, m),
                };
                v.* = cell orelse {
                    arr.release(w.gpa);
                    return null;
                };
            }

            //TODO: array downcast
            return Cell.array(arr);
        },
        .string => {
            const s = w.str(t);
            const inner = s[1 .. s.len - 1];

            const sh = [_]sbl.Array.Dim{@intCast(inner.len)};
            // TODO: u32 array
            var arr = try sbl.Array.init(w.gpa, &sh, .any);
            const cells = arr.any_slice();

            var count = @as(usize, 0);
            var i = @as(usize, 0);
            while (i < inner.len) : (count += 1) {
                const ch, const incr = decode_str_char(inner, i) orelse {
                    arr.release(w.gpa);
                    return w.invalid(t);
                };
                cells[count] = Cell.char(ch);
                i += incr;
            }

            errdefer arr.release(w.gpa);
            if (count < inner.len) arr = try arr.shrink(w.gpa, count);
            return Cell.array(arr);
        },
        else => return null,
    }
}

fn strip_num(buf: []u8, text: []const u8) ?[]const u8 {
    var n: usize = 0;
    for (text) |c| {
        if (c == '_') continue;
        if (n >= buf.len) return null;
        buf[n] = c;
        n += 1;
    }
    return buf[0..n];
}

fn decode_str_char(s: []const u8, i: usize) ?struct { u32, usize } {
    if (s[i] == '\\') {
        if (i + 1 >= s.len) return null;
        const cp: u32 = switch (s[i + 1]) {
            'n' => '\n',
            't' => '\t',
            'r' => '\r',
            '0' => 0,
            '\\' => '\\',
            '"' => '"',
            else => return null,
        };
        return .{ cp, 2 };
    }

    const len = std.unicode.utf8ByteSequenceLength(s[i]) catch return null;
    if (i + len > s.len) return null;
    const cp = std.unicode.utf8Decode(s[i..][0..len]) catch return null;
    return .{ cp, len };
}

fn invalid(w: *Compiler, t: sbl.Token.Index) Error!?Cell {
    try w.fail_p(.invalid_token, w.ts.items(.pos)[t]);
    return null;
}

fn emit(w: *Compiler, inst: sbl.bc.Inst, n: Node.Index) !void {
    const t: Span = w.ts.items(.pos)[w.node(.token, n)];
    const u: Span = w.ts.items(.pos)[w.node(.token_end, n)];
    try w.emit_p(inst, Span.span(t.start, u.end));
}

fn emit_p(w: *Compiler, inst: sbl.bc.Inst, p: Span) !void {
    try w.code.bc.append(w.gpa, inst);
    try w.code.loc.append(w.gpa, p);
}

fn fail(w: *Compiler, k: sbl.CompileError.Kind, n: Node.Index) !void {
    const t: Span = w.ts.items(.pos)[w.node(.token, n)];
    const u: Span = w.ts.items(.pos)[w.node(.token_end, n)];
    try w.fail_p(k, Span.span(t.start, u.end));
}

fn fail_p(w: *Compiler, k: sbl.CompileError.Kind, p: Span) !void {
    try w.errs.append(w.gpa, .{ .kind = k, .pos = p });
}

fn kind(w: *Compiler, tok: u32) sbl.Token.Kind {
    return w.ts.items(.kind)[tok];
}

fn span(w: *Compiler, tok: u32) Span {
    return w.ts.items(.pos)[tok];
}

fn str(w: *Compiler, tok: u32) []const u8 {
    return w.span(tok).slice(w.buf);
}

fn node(w: *Compiler, comptime k: @EnumLiteral(), n: Node.Index) @TypeOf(w.ast.tree.items(k)[0]) {
    return w.ast.tree.items(k)[n];
}

fn intern(w: *Compiler, s: []const u8) E!Symbol {
    return w.st.intern(s);
}

fn lookup(w: *Compiler, s: Symbol) ?Def {
    const i: usize = @backingInt(s);
    if (i >= w.env.items.len) return null;
    return w.env.items[i];
}

fn bind(w: *Compiler, s: Symbol, d: Def) E!void {
    std.debug.assert(s != .none);
    const i: usize = @backingInt(s);
    if (i >= w.env.items.len)
        try w.env.appendNTimes(w.gpa, null, i + 1 - w.env.items.len);
    w.env.items[i] = d;
}

fn lambda(w: *Compiler, body: Node.Index) E!usize {
    const prev = w.code;
    w.code = .{};
    errdefer {
        w.code.deinit(w.gpa);
        w.code = prev;
    }

    try w.expr(body);
    try w.emit(.ret, body);

    const idx = w.fns.items.len;
    try w.fns.append(w.gpa, w.code);

    w.code = prev;

    return w.lam_base + idx;
}

const Compiler = @This();
const std = @import("std");
const sbl = @import("sbl");
const Cell = sbl.Cell;
const Inst = sbl.bc.Inst;
const Node = sbl.Syntax.Node;
const Span = sbl.SourceFile.Span;
const StackEffect = sbl.bc.StackEffect;
const Symbol = sbl.SymTable.Symbol;
