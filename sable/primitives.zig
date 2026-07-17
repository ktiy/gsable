const std = @import("std");

const Token = @import("Token.zig");

pub fn token_from_cp(c: u21) Token.Kind {
    return switch (c) {
        '.' => .dup, //    a -- a a
        ',' => .drop,//    a --
        '~' => .swap,//  a b -- b a
        '⫦' => .over,//  a b -- a b a
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
