const std = @import("std");
const sbl = @import("sbl");
const Token = sbl.Token;

pub fn token_from_cp(c: u21) Token.Kind {
    return switch (c) {
        '.' => .dup, //     x -- x x
        ',' => .drop, //    x --
        '~' => .swap, //  a x -- x a
        '⫦' => .over, //  a x -- a x a
        '⊪' => .rot, // j a x -- a x j
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

pub const Prim = fn (m: *sbl.Machine) void;

pub fn run(t: Token.Kind) *const Prim {
    const arith = @import("prim/arith.zig");
    const sort = @import("prim/sort.zig");
    const stack = @import("prim/stack.zig");
    const nyi = @import("prim/nyi.zig");
    return switch (t) {
        .dup => stack.dup,
        .drop => stack.drop,
        .swap => stack.swap,
        .over => stack.over,
        .rot => stack.rot,
        .length => @import("prim/length.zig").run,
        .order_up => sort.up,
        .order_down => sort.down,
        .add => arith.add,
        .sub => arith.sub,
        .mul => arith.mul,
        .div => arith.div,
        .pow => arith.pow,
        .mod => arith.mod,
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
