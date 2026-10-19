const std = @import("std");

const Token = @import("Token.zig");

pub fn token_from_cp(c: u21) Token.Kind {
    return switch (c) {
        '.' => .dup, //    a -- a a
        ',' => .drop, //    a --
        '~' => .swap, //  a b -- b a
        '⫦' => .over, //  a b -- a b a
        '⊪' => .rot, //a b c -- b c a
        'ι' => .iota,
        'ρ' => .shape,
        '⧻' => .length,
        '△' => .order_up,
        '▽' => .order_down,
        '□' => .peek,
        'Ρ' => .reshape,
        '+' => .add,
        '-' => .sub,
        '×' => .mul,
        '÷' => .div,
        '*' => .pow,
        '|' => .mod,
        '´' => .fold,
        else => .unknown,
    };
}

pub fn Prim(t: Token.Kind) type {
    return switch (t) {
        else => @import("prim/nyi.zig"),
    };
}

pub fn is_prim(k: Token.Kind) bool {
    const i: u8 = @intFromEnum(Token.Kind.dup);
    const j: u8 = @intFromEnum(Token.Kind.mod);
    const x: u8 = @intFromEnum(k);
    return x >= i and x <= j;
}

pub fn is_mod(k: Token.Kind) bool {
    return k == .fold;
}
