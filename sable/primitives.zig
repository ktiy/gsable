const std = @import("std");

const Token = @import("Token.zig");

pub fn token_from_cp(c: u21) Token.Kind {
    return switch (c) {
        '⋅' => .dup,
        '∘' => .drop,
        '↔' => .swap,
        '⇒' => .over,
        '⇔' => .rot,
        'ι' => .iota,
        'ρ' => .shape,
        '⋕' => .length,
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
        else => .unknown,
    };
}
