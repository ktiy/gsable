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
        '`' => .scan,
        else => .unknown,
    };
}

pub const Prim = fn (m: *sbl.Machine) void;
pub const Mod = fn (m: *sbl.Machine, f: usize) void;

pub fn run(t: Token.Kind) *const Prim {
    const arith = @import("prim/arith.zig");
    const sort = @import("prim/sort.zig");
    const shape = @import("prim/shape.zig");
    const stack = @import("prim/stack.zig");
    const nyi = @import("prim/nyi.zig");
    return switch (t) {
        .dup => stack.dup,
        .drop => stack.drop,
        .swap => stack.swap,
        .over => stack.over,
        .rot => stack.rot,
        .iota => @import("prim/iota.zig").run,
        .length => @import("prim/length.zig").run,
        .peek => @import("prim/peek.zig").run,
        .shape => shape.run,
        .reshape => shape.re,
        .order_up => sort.up,
        .order_down => sort.down,
        .add => arith.add,
        .sub => arith.sub,
        .mul => arith.mul,
        .div => arith.div,
        .pow => arith.pow,
        .mod => arith.mod,
        else => nyi.run,
    };
}

pub fn mod(t: Token.Kind) *const Mod {
    return switch (t) {
        .fold => @import("mod/fold.zig").run,
        .scan => @import("mod/scan.zig").run,
        else => unreachable,
    };
}

pub fn is_prim(k: Token.Kind) bool {
    const i: u8 = @backingInt(Token.Kind.dup);
    const j: u8 = @backingInt(Token.Kind.mod);
    const x: u8 = @backingInt(k);
    return x >= i and x <= j;
}

pub fn is_mod(k: Token.Kind) bool {
    const i: u8 = @backingInt(Token.Kind.fold);
    const j: u8 = @backingInt(Token.Kind.scan);
    const x: u8 = @backingInt(k);
    return x >= i and x <= j;
}
