const Syntax = @This();

const std = @import("std");
const Token = @import("Token.zig");
const SourceFile = @import("SourceFile.zig");
const CompileError = @import("CompileError.zig");
const prim = @import("primitives.zig");

tree: Node.Slice,
root: Node.Index,
extra: []Node.Index,

pub fn deinit(ast: *Syntax, gpa: std.mem.Allocator) void {
    ast.tree.deinit(gpa);
    gpa.free(ast.extra);
    ast.root = 0;
}

pub fn dump(
    ast: Syntax,
    w: *std.Io.Writer,
    tokens: Token.Slice,
    buf: []const u8,
) !void {
    try report.write_node(w, ast, tokens, buf, ast.root, "", true, true);
}

const report = struct {
    fn write_node(
        w: *std.Io.Writer,
        ast: Syntax,
        tokens: Token.Slice,
        buf: []const u8,
        idx: Node.Index,
        prefix: []const u8,
        is_last: bool,
        is_root: bool,
    ) !void {
        const node = ast.tree.get(idx);
        const connector: []const u8 =
            if (is_root) "" else if (is_last) "└─" else "├─";
        try w.print("{s}{s}{s}", .{ prefix, connector, @tagName(node.kind) });

        switch (node.kind) {
            .builtin, .symbol, .real, .byte, .string, .primitive, .modifier => {
                const pos = tokens.items(.pos)[node.token];
                const loc = pos.line_col(buf);
                try w.print(" \"{s}\" ({d}:{d})\n", .{ pos.slice(buf), loc.line, loc.column });
            },
            .assign, .modify => {
                try w.print("\n", .{});

                var prefix_buf: [512]u8 = undefined;
                const child_prefix = try child_prefix_buf(&prefix_buf, prefix, is_last, is_root);
                try write_node(w, ast, tokens, buf, node.lhs, child_prefix, false, false);
                try write_node(w, ast, tokens, buf, node.rhs, child_prefix, true, false);
            },
            .array, .sequence => {
                const children = ast.extra[node.lhs..node.rhs];
                try w.print(" [{d}]\n", .{children.len});
                var prefix_buf: [512]u8 = undefined;
                const child_prefix = try child_prefix_buf(&prefix_buf, prefix, is_last, is_root);
                for (children, 0..) |c, i| {
                    try write_node(w, ast, tokens, buf, c, child_prefix, i == children.len - 1, false);
                }
            },
        }
    }

    fn child_prefix_buf(buf: []u8, prefix: []const u8, is_last: bool, is_root: bool) ![]const u8 {
        if (is_root) return prefix;
        return std.fmt.bufPrint(buf, "{s}{s}", .{ prefix, if (is_last) "   " else "│  " });
    }
};

pub const Node = struct {
    kind: Kind,
    token: Token.Index,
    token_end: Token.Index,
    lhs: u32,
    rhs: u32,

    pub const List = std.MultiArrayList(Node);
    pub const Slice = List.Slice;
    pub const Index = u32;

    pub const Kind = enum {
        // atoms
        builtin,
        symbol,
        real,
        byte,
        string,
        primitive,
        modifier,

        // lhs: symbol, rhs: node
        assign,

        // lhs: function, rhs: modifier
        modify,

        // lhs: extra start, rhs: extra end
        array,
        sequence,
    };

    pub fn init(k: Kind, t: Token.Index) Node {
        return .{
            .kind = k,
            .token = t,
            .token_end = undefined,
            .lhs = undefined,
            .rhs = undefined,
        };
    }

    pub fn node(k: Kind, t: Token.Index, u: Token.Index, lhs: u32, rhs: u32) Node {
        return .{
            .kind = k,
            .token = t,
            .token_end = u,
            .lhs = lhs,
            .rhs = rhs,
        };
    }
};

pub const Parser = struct {
    gpa: std.mem.Allocator,

    /// externally owned
    tokens: Token.Slice,
    pos: Token.Index = 0,

    nodes: Node.List = .empty,
    tmp: std.ArrayList(Node.Index) = .empty,
    extra: std.ArrayList(Node.Index) = .empty,

    errors: std.ArrayList(CompileError) = .empty,

    pub const Error = std.mem.Allocator.Error;

    pub fn init(gpa: std.mem.Allocator, tokens: Token.Slice) Parser {
        return .{ .gpa = gpa, .tokens = tokens };
    }

    pub fn deinit(p: *Parser) void {
        p.tmp.deinit(p.gpa);
        p.errors.deinit(p.gpa);
    }

    pub fn parse(p: *Parser) Error!Syntax {
        const root_node = try p.parse_stmt_list(.eof);
        const root = try p.push(root_node);

        return .{
            .tree = p.nodes.toOwnedSlice(),
            .root = root,
            .extra = try p.extra.toOwnedSlice(p.gpa),
        };
    }

    fn parse_stmt_list(p: *Parser, term: Token.Kind) Error!Node {
        const start_tok = p.pos;

        const scratch_start = p.tmp.items.len;
        defer p.tmp.shrinkRetainingCapacity(scratch_start);

        p.skip_seps();
        while (p.kind() != term and p.kind() != .eof) {
            const stmt = (try p.parse_stmt()) orelse break;
            const idx = try p.push(stmt);
            try p.tmp.append(p.gpa, idx);

            if (p.kind() == .semicolon or p.kind() == .newline or p.kind() == .comment_line) {
                p.skip_seps();
            } else break;
        }

        const extra_start: u32 = @intCast(p.extra.items.len);
        try p.extra.appendSlice(p.gpa, p.tmp.items[scratch_start..]);
        const extra_end: u32 = @intCast(p.extra.items.len);

        return .node(.sequence, start_tok, p.pos, extra_start, extra_end);
    }

    fn parse_stmt(p: *Parser) Error!?Node {
        if (p.kind() == .symbol and p.peek(1) == .left_arrow) {
            const sym_tok = p.incr();
            const sym_idx = try p.push(.init(.symbol, sym_tok));
            _ = p.incr();

            const rhs = (try p.parse_train()) orelse {
                try p.push_err(.expected_expression, p.pos);
                return .node(.assign, sym_tok, p.pos, sym_idx, undefined);
            };
            const rhs_idx = try p.push(rhs);

            return .node(.assign, sym_tok, p.pos, sym_idx, rhs_idx);
        }

        return p.parse_train();
    }

    fn parse_train(p: *Parser) Error!?Node {
        const start_tok = p.pos;

        const first = (try p.parse_mod()) orelse return null;
        const second = (try p.parse_mod()) orelse return first;

        const scratch_start = p.tmp.items.len;
        defer p.tmp.shrinkRetainingCapacity(scratch_start);

        try p.tmp.append(p.gpa, try p.push(first));
        try p.tmp.append(p.gpa, try p.push(second));
        while (try p.parse_mod()) |m| {
            try p.tmp.append(p.gpa, try p.push(m));
        }

        const extra_start: u32 = @intCast(p.extra.items.len);
        try p.extra.appendSlice(p.gpa, p.tmp.items[scratch_start..]);
        const extra_end: u32 = @intCast(p.extra.items.len);

        return .node(.sequence, start_tok, p.pos, extra_start, extra_end);
    }

    fn parse_mod(p: *Parser) Error!?Node {
        const first_tok = p.pos;
        const first = (try p.parse_operand()) orelse return null;

        if (prim.is_mod(p.kind())) {
            const mod_tok = p.incr();
            const mod_idx = try p.push(.init(.modifier, mod_tok));
            const first_idx = try p.push(first);
            return .node(.modify, mod_tok, p.pos, first_idx, mod_idx);
        }

        return p.parse_strand_body(first_tok, first);
    }

    fn parse_strand(p: *Parser) Error!?Node {
        const first_tok = p.pos;
        const first = (try p.parse_operand()) orelse return null;

        return p.parse_strand_body(first_tok, first);
    }

    fn parse_strand_body(p: *Parser, first_tok: Token.Index, first: Node) Error!?Node {
        if (p.kind() != .strand) return first;

        const scratch_start = p.tmp.items.len;
        defer p.tmp.shrinkRetainingCapacity(scratch_start);

        try p.tmp.append(p.gpa, try p.push(first));
        while (p.kind() == .strand) {
            const strand = p.incr();
            const next = (try p.parse_operand()) orelse {
                try p.push_err(.dangling_strand, strand);
                break;
            };
            try p.tmp.append(p.gpa, try p.push(next));
        }

        const extra_start: u32 = @intCast(p.extra.items.len);
        try p.extra.appendSlice(p.gpa, p.tmp.items[scratch_start..]);
        const extra_end: u32 = @intCast(p.extra.items.len);

        return .node(.array, first_tok, p.pos, extra_start, extra_end);
    }

    fn parse_operand(p: *Parser) Error!?Node {
        return switch (p.kind()) {
            .brace_open => p.parse_block(),
            .array_open => p.parse_array(),
            else => p.parse_atom(),
        };
    }

    fn parse_block(p: *Parser) Error!?Node {
        const open = p.incr();
        const body = try p.parse_stmt_list(.brace_close);
        if (p.kind() != .brace_close) {
            try p.push_err(.expected_brace_close, p.pos);
            return .node(.sequence, open, undefined, body.lhs, body.rhs);
        }
        const close = p.incr();
        return .node(.sequence, open, close, body.lhs, body.rhs);
    }

    fn parse_array(p: *Parser) Error!?Node {
        const open = p.incr();
        const body = try p.parse_stmt_list(.array_close);
        if (p.kind() != .array_close) {
            try p.push_err(.expected_array_close, p.pos);
            return .node(.array, open, undefined, body.lhs, body.rhs);
        }
        const close = p.incr();
        return .node(.array, open, close, body.lhs, body.rhs);
    }

    fn parse_atom(p: *Parser) ?Node {
        const k = p.kind();
        return switch (k) {
            .builtin => .init(.builtin, p.incr()),
            .symbol => .init(.symbol, p.incr()),
            .byte => .init(.byte, p.incr()),
            .real => .init(.real, p.incr()),
            .string => .init(.string, p.incr()),
            else => if (prim.is_prim(k))
                .init(.primitive, p.incr())
            else
                null,
        };
    }

    fn push_err(p: *Parser, err: CompileError.Kind, pos: Token.Index) !void {
        try p.errors.append(p.gpa, .{ .kind = err, .pos = p.tokens.items(.pos)[pos] });
    }

    fn push(p: *Parser, node: Node) Error!Node.Index {
        try p.nodes.append(p.gpa, node);
        return @intCast(p.nodes.len - 1);
    }

    fn incr(p: *Parser) u32 {
        const x = p.pos;
        p.pos += 1;
        return x;
    }

    fn decr(p: *Parser) void {
        std.debug.assert(p.pos >= 1);
        p.pos -= 1;
    }

    fn skip_seps(p: *Parser) void {
        while (p.kind() == .semicolon or p.kind() == .newline or p.kind() == .comment_line) p.pos += 1;
    }

    fn skip_trivia(p: *Parser) void {
        while (p.pos < p.tokens.len) : (p.pos += 1) {
            switch (p.tokens.items(.kind)[p.pos]) {
                .comment => {},
                else => return,
            }
        }
    }

    fn kind(p: *Parser) Token.Kind {
        p.skip_trivia();
        if (p.pos >= p.tokens.len) return .eof;
        return p.tokens.items(.kind)[p.pos];
    }

    fn peek(p: *Parser, offset: u32) Token.Kind {
        var i = p.pos;
        var seen: u32 = 0;
        while (i < p.tokens.len) : (i += 1) {
            switch (p.tokens.items(.kind)[i]) {
                .comment => continue,
                else => {
                    if (seen == offset) return p.tokens.items(.kind)[i];
                    seen += 1;
                },
            }
        }
        return .eof;
    }

    fn src(p: *Parser) SourceFile.Span {
        return p.tokens.items(.pos)[p.pos];
    }
};
