const Token = @This();

const SourceFile = @import("SourceFile.zig");
const primitives = @import("primitives.zig");

kind: Kind,
pos: SourceFile.Span,

pub const List = std.MultiArrayList(Token);
pub const Slice = List.Slice;
pub const Index = u32;

pub const Kind = enum {
    comment,
    builtin,
    symbol,
    byte,
    real,
    string,
    lambda,
    array_open,
    array_close,
    brace_open,
    brace_close,
    left_arrow,
    semicolon,
    strand,

    // stack
    dup,
    drop,
    swap,
    over,
    rot,

    // monad
    iota,
    shape,
    length,
    order_up,
    order_down,

    // dyad
    peek,
    reshape,
    add,
    sub,
    mul,
    div,
    pow,
    mod,

    eof,
    unknown,
};

const log = std.log.scoped(.lexer);

// TODO: proper error handling (other than Lexer.panic)
// TODO: symbols should allow more than just the latin alphabet
pub const Lexer = struct {
    path: []const u8,
    buf: [:0]const u8,
    pos: u32,
    cache: ?struct { u21, u3 } = null,

    pub fn init(src: SourceFile, pos: u32) Lexer {
        return .{
            .path = src.path,
            .buf = src.content,
            .pos = pos,
        };
    }

    pub fn next(lex: *Lexer) Token {
        var t = Token{
            .kind = .unknown,
            .pos = .span(lex.pos, lex.pos),
        };

        const State = enum {
            start,
            comment_line,
            comment_paren,
            symbol,
            number_dec,
            number_hex,
            number_frac,
            number_exp_start,
            number_exp,
            string_start,
            string_backslash,
        };

        var comment_depth: usize = 0;

        state: switch (State.start) {
            .start => switch (lex.peek()) {
                0 => {
                    t.kind = .eof;
                    return t;
                },
                ' ', '\r', '\n' => {
                    lex.incr();
                    t.pos.start = lex.pos;
                    continue :state .start;
                },
                '%' => {
                    lex.incr();
                    t.kind = .comment;
                    continue :state .comment_line;
                },
                '(' => {
                    lex.incr();
                    t.kind = .comment;
                    continue :state .comment_paren;
                },
                'a'...'z', 'A'...'Z', '_' => {
                    lex.incr();
                    t.kind = .symbol;
                    continue :state .symbol;
                },
                '0'...'9' => {
                    lex.incr();
                    t.kind = .real;
                    continue :state .number_dec;
                },
                '#' => {
                    lex.incr();
                    t.kind = .byte;
                    continue :state .number_hex;
                },
                '"' => {
                    lex.incr();
                    t.kind = .string;
                    continue :state .string_start;
                },
                ';', '⋄' => t.kind = lex.atom(.semicolon),
                'λ' => t.kind = lex.atom(.lambda),
                '←' => t.kind = lex.atom(.left_arrow),
                '[' => t.kind = lex.atom(.array_open),
                ']' => t.kind = lex.atom(.array_close),
                '{' => t.kind = lex.atom(.brace_open),
                '}' => t.kind = lex.atom(.brace_close),
                '‿' => t.kind = lex.atom(.strand),
                else => |cp| {
                    const prim = primitives.token_from_cp(cp);
                    if (prim == .unknown) lex.panic("unexpected character");
                    t.kind = lex.atom(prim);
                },
            },
            .comment_line => switch (lex.peek()) {
                0 => {
                    t.kind = .eof;
                    return t;
                },
                '\n' => {
                    lex.incr();
                },
                else => {
                    lex.incr();
                    continue :state .comment_line;
                },
            },
            .comment_paren => switch (lex.peek()) {
                0 => {
                    lex.panic("unexpected EOF");
                },
                '(' => {
                    lex.incr();
                    comment_depth += 1;
                    continue :state .comment_paren;
                },
                ')' => {
                    lex.incr();
                    if (comment_depth > 0) {
                        comment_depth -= 1;
                        continue :state .comment_paren;
                    }
                },
                else => {
                    lex.incr();
                    continue :state .comment_paren;
                },
            },
            .symbol => switch (lex.peek()) {
                'a'...'z', 'A'...'Z', '0'...'9', '_' => {
                    lex.incr();
                    continue :state .symbol;
                },
                else => {},
            },
            .number_dec => switch (lex.peek()) {
                '0'...'9', '_' => {
                    lex.incr();
                    continue :state .number_dec;
                },
                '.' => {
                    lex.incr();
                    continue :state .number_frac;
                },
                'e', 'E' => {
                    lex.incr();
                    continue :state .number_exp_start;
                },
                else => {},
            },
            .number_frac => switch (lex.peek()) {
                '0'...'9', '_' => {
                    lex.incr();
                    continue :state .number_frac;
                },
                'e', 'E' => {
                    lex.incr();
                    continue :state .number_exp_start;
                },
                else => {},
            },
            .number_exp_start => switch (lex.peek()) {
                '+', '-' => {
                    lex.incr();
                    continue :state .number_exp;
                },
                '0'...'9', '_' => {
                    lex.incr();
                    continue :state .number_exp;
                },
                else => {},
            },
            .number_exp => switch (lex.peek()) {
                '0'...'9', '_' => {
                    lex.incr();
                    continue :state .number_exp;
                },
                else => {},
            },
            .number_hex => switch (lex.peek()) {
                '0'...'9', 'a'...'f', 'A'...'F', '_' => {
                    lex.incr();
                    continue :state .number_hex;
                },
                else => {},
            },
            .string_start => switch (lex.peek()) {
                '"' => {
                    lex.incr();
                },
                '\\' => {
                    lex.incr();
                    continue :state .string_backslash;
                },
                '\n', 0 => lex.panic("expected `\"`"),
                else => {
                    lex.incr();
                    continue :state .string_start;
                },
            },
            .string_backslash => switch (lex.peek()) {
                '\n', 0 => lex.panic("expected  `\"'"),
                else => {
                    lex.incr();
                    continue :state .string_start;
                },
            },
        }

        t.pos.end = lex.pos;
        return t;
    }

    pub fn collect(lex: *Lexer, gpa: std.mem.Allocator) !Slice {
        var list: List = .empty;
        defer list.deinit(gpa);

        while (true) {
            const t = lex.next();
            if (t.kind == .eof) break;
            try list.append(gpa, t);
        }

        return list.toOwnedSlice();
    }

    fn peek(lex: *Lexer) u21 {
        if (lex.pos >= lex.buf.len) return 0;
        if (lex.cache) |cache| return cache[0];

        const e = "invalid utf-8";
        const len = std.unicode.utf8ByteSequenceLength(lex.buf[lex.pos]) catch lex.panic(e);
        const cp = std.unicode.utf8Decode(lex.buf[lex.pos..][0..len]) catch lex.panic(e);

        lex.cache = .{ cp, len };
        return cp;
    }

    fn incr(lex: *Lexer) void {
        _, const len = lex.cache.?;
        lex.pos += len;
        lex.cache = null;
    }

    fn atom(lex: *Lexer, x: Token.Kind) Token.Kind {
        lex.incr();
        return x;
    }

    fn panic(lex: *Lexer, str: []const u8) noreturn {
        log.err("{s}: {s}", .{ lex.path, str });
        std.process.exit(1);
    }
};

test "lexer" {
    const gpa = std.testing.allocator;

    const src = SourceFile{ .path = "example", .content =
        \\1‿2ι3+ %comment
        \\[3](comment(nested))0-
        \\"hello\n"
    };

    const expect = [_]Token.Kind{
        .real,
        .strand,
        .real,
        .iota,
        .real,
        .add,
        .comment,
        .array_open,
        .real,
        .array_close,
        .comment,
        .real,
        .sub,
        .string,
    };

    var lex = Lexer.init(src, 0);
    var all = try lex.collect(gpa);
    defer all.deinit(gpa);

    try std.testing.expectEqual(expect.len, all.len);
    for (all.items(.kind), expect) |got, expected| {
        try std.testing.expectEqual(expected, got);
    }
}

const std = @import("std");
