const std = @import("std");
const sbl = @import("sbl");
const Token = sbl.Token;

pub fn token_from_cp(c: u21) Token.Kind {
    return switch (c) {
        '.' => .dup, //     x -- x x
        ',' => .drop, //    x --
        '~' => .swap, //  x a -- a x
        '⫦' => .over, //  x a -- x a x
        '⊪' => .rot, // x a j -- a j x
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

pub fn run(t: Token.Kind) *const fn (m: *sbl.Machine) void {
    const stack = @import("prim/stack.zig");
    const nyi = @import("prim/nyi.zig");
    return switch (t) {
        .dup => stack.dup,
        .drop => stack.drop,
        .swap => stack.swap,
        .over => stack.over,
        .rot => stack.rot,
        .iota => @import("prim/iota.zig").run,
        else => nyi.run,
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
