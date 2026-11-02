pub const Builtin = enum {
    echo, // x -- x
    print, // x --
};

pub const map = std.StaticStringMap(Builtin).initComptime(&.{
    .{ "echo", .echo },
    .{ "print", .print },
});

pub fn stack_effect(b: Builtin) Stack_Effect {
    return switch (b) {
        .echo => .init(1, 1),
        .print => .init(1, 0),
    };
}

pub fn run(m: M, b: Builtin) void {
    return switch (b) {
        .echo => echo(m),
        .print => print(m),
    };
}

fn echo(m: M) void {
    const x = m.top();
    std.debug.print("{f}\n", .{x.*});
}

fn print(m: M) void {
    const x = m.pop();
    std.debug.print("{f}", .{x});
}

const M = *sbl.Machine;
const Stack_Effect = sbl.bc.StackEffect;

const std = @import("std");
const sbl = @import("sbl");
