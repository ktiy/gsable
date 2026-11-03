kind: Kind,
pos: SourceFile.Span,

pub const List = std.MultiArrayList(Token);
pub const Slice = List.Slice;
pub const Index = u32;

pub const Kind = enum(u8) {
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
    not,

    // dyad
    peek,
    reshape,
    eq,
    neq,
    lt,
    lt_eq,
    gt,
    gt_eq,

    add,
    sub,
    mul,
    div,
    pow,
    mod,
    min,
    max,

    // modifiers
    fold,
    scan,

    comment,
    comment_line,
    newline,

    eof,
    unknown,
};

const log = std.log.scoped(.lexer);

// TODO: proper error handling (other than Lexer.panic)
// TODO: symbols should allow more than just the latin alphabet
pub const Lexer = struct {
    buf: [:0]const u8,
    pos: u32,
    cache: ?struct { u21, u3 } = null,

    pub fn init(content: [:0]const u8, pos: u32) Lexer {
        return .{
            .buf = content,
            .pos = pos,
        };
    }

    pub const Error = error{
        invalid_utf8,
        unclosed_string,
        unclosed_comment,
        unexpected_character,
    };

    pub fn next(lex: *Lexer) Error!Token {
        var t = Token{
            .kind = .unknown,
            .pos = .span(lex.pos, lex.pos),
        };

        const State = enum {
            start,
            start_backslash,
            newline,
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
            .start => switch (try lex.peek()) {
                0 => {
                    t.kind = .eof;
                    return t;
                },
                '\\' => {
                    lex.incr();
                    continue :state .start_backslash;
                },
                ' ', '\t', '\r' => {
                    lex.incr();
                    t.pos.start = lex.pos;
                    continue :state .start;
                },
                '\n' => {
                    lex.incr();
                    t.kind = .newline;
                    continue :state .newline;
                },
                '%' => {
                    lex.incr();
                    t.kind = .comment_line;
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
                '@' => {
                    lex.incr();
                    t.kind = .builtin;
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
                '¬' => t.kind = lex.atom(.not),
                '=' => t.kind = lex.atom(.eq),
                '≠' => t.kind = lex.atom(.neq),
                '>' => t.kind = lex.atom(.gt),
                '≥' => t.kind = lex.atom(.gt_eq),
                '<' => t.kind = lex.atom(.lt),
                '≤' => t.kind = lex.atom(.lt_eq),
                '↧' => t.kind = lex.atom(.min),
                '↥' => t.kind = lex.atom(.max),
                else => |cp| {
                    const prim = primitives.token_from_cp(cp);
                    if (prim == .unknown) return Error.unexpected_character;
                    t.kind = lex.atom(prim);
                },
            },
            .start_backslash => switch (try lex.peek()) {
                '\n' => {
                    lex.incr();
                    continue :state .start;
                },
                else => return Error.unexpected_character,
            },
            .newline => switch (try lex.peek()) {
                ' ', '\t', '\r', '\n' => {
                    lex.incr();
                    continue :state .newline;
                },
                else => {},
            },
            .comment_line => switch (try lex.peek()) {
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
            .comment_paren => switch (try lex.peek()) {
                0 => {
                    return Error.unclosed_comment;
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
            .symbol => switch (try lex.peek()) {
                'a'...'z', 'A'...'Z', '0'...'9', '_' => {
                    lex.incr();
                    continue :state .symbol;
                },
                else => {},
            },
            .number_dec => switch (try lex.peek()) {
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
            .number_frac => switch (try lex.peek()) {
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
            .number_exp_start => switch (try lex.peek()) {
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
            .number_exp => switch (try lex.peek()) {
                '0'...'9', '_' => {
                    lex.incr();
                    continue :state .number_exp;
                },
                else => {},
            },
            .number_hex => switch (try lex.peek()) {
                '0'...'9', 'a'...'f', 'A'...'F', '_' => {
                    lex.incr();
                    continue :state .number_hex;
                },
                else => {},
            },
            .string_start => switch (try lex.peek()) {
                '"' => {
                    lex.incr();
                },
                '\\' => {
                    lex.incr();
                    continue :state .string_backslash;
                },
                '\n', 0 => return Error.unclosed_string,
                else => {
                    lex.incr();
                    continue :state .string_start;
                },
            },
            .string_backslash => switch (try lex.peek()) {
                '\n', 0 => return Error.unclosed_string,
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
            const t = try lex.next();
            try list.append(gpa, t);
            if (t.kind == .eof) break;
        }

        return list.toOwnedSlice();
    }

    fn peek(lex: *Lexer) !u21 {
        if (lex.pos >= lex.buf.len) return 0;
        if (lex.cache) |cache| return cache[0];

        const buf = lex.buf[lex.pos..];
        const len = utf.utf8ByteSequenceLength(buf[0]) catch return Error.invalid_utf8;
        const cp = utf.utf8Decode(buf[0..len]) catch return Error.invalid_utf8;

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

    const src =
        \\1‿2ι3+ %comment
        \\[3](comment(nested))0-
        \\"hello\n"
    ;

    const expect = [_]Token.Kind{
        .real,
        .strand,
        .real,
        .iota,
        .real,
        .add,
        .comment_line,
        .array_open,
        .real,
        .array_close,
        .comment,
        .real,
        .sub,
        .newline,
        .string,
        .eof,
    };

    var lex = Lexer.init(src, 0);
    var all = try lex.collect(gpa);
    defer all.deinit(gpa);

    try std.testing.expectEqual(expect.len, all.len);
    for (all.items(.kind), expect) |got, expected| {
        try std.testing.expectEqual(expected, got);
    }
}

test "lexer invalid character" {
    const gpa = std.testing.allocator;
    var lex = Lexer.init("a↢", 0);
    const result = lex.collect(gpa);
    try std.testing.expectError(error.unexpected_character, result);
    try std.testing.expectEqual(1, lex.pos);
}

test "lexer unclosed comment" {
    const gpa = std.testing.allocator;
    var lex = Lexer.init("(", 0);
    const result = lex.collect(gpa);
    try std.testing.expectError(error.unclosed_comment, result);
    try std.testing.expectEqual(1, lex.pos);
}

test "lexer unclosed string" {
    const gpa = std.testing.allocator;
    var lex = Lexer.init("\"", 0);
    const result = lex.collect(gpa);
    try std.testing.expectError(error.unclosed_string, result);
    try std.testing.expectEqual(1, lex.pos);
}

test "invalid utf-8" {
    const gpa = std.testing.allocator;
    var lex = Lexer.init(".\xc3\x28", 0);
    const result = lex.collect(gpa);
    try std.testing.expectError(error.invalid_utf8, result);
    try std.testing.expectEqual(1, lex.pos);
}

const Token = @This();
const std = @import("std");
const sbl = @import("sbl");
const utf = std.unicode;
const primitives = sbl.primitives;
const SourceFile = sbl.SourceFile;
