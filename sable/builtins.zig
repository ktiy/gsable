pub const Builtin = enum {
    echo,
    print,
    putc,
    w,
    frc,
    frb,
    debug_array,
};

pub const map = std.StaticStringMap(Builtin).initComptime(&.{
    .{ "echo", .echo },
    .{ "print", .print },
    .{ "putc", .putc },
    .{ "w", .w },
    .{ "frc", .frc },
    .{ "frb", .frb },
    .{ "debug_array", .debug_array },
});

pub fn stack_effect(b: Builtin) Stack_Effect {
    return switch (b) {
        .echo => .init(1, 1),
        .print => .init(1, 0),
        .putc => .init(1, 0),
        .w => .init(1, 0),
        .frc => .init(1, 1),
        .frb => .init(1, 1),
        .debug_array => .init(1, 1),
    };
}

pub fn run(m: M, b: Builtin) void {
    return switch (b) {
        .echo => echo(m),
        .print => print(m),
        .putc => putc(m),
        .w => w(m),
        .frc => frc(m),
        .frb => frb(m),
        .debug_array => debug_array(m),
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

fn putc(m: M) void {
    const x = m.pop();
    if (x.k != .char) return m.throw(.type);
    const u: u21 = @truncate(x.into(.char));
    std.debug.print("{u}", .{u});
}

fn w(m: M) void {
    const x = m.pop();
    if (x.atom()) return m.throw(.type);

    const arr = x.into(.array);
    defer arr.release(m.gpa);

    if (arr.ty() != .char) return m.throw(.type);

    const stdout: std.Io.File = .stdout();
    var stdout_buf: [1024]u8 = undefined;
    var stdout_writer = stdout.writer(m.io, &stdout_buf);
    const writer = &stdout_writer.interface;
    for (arr.char_slice()) |cp| {
        const c: u21 = @intCast(cp);
        writer.print("{u}", .{c}) catch return m.throw(.os);
    }

    writer.flush() catch return m.throw(.os);
}

fn frc(m: M) void {
    const x = m.pop();
    if (x.atom()) return m.throw(.type);

    const arr = x.into(.array);
    defer arr.release(m.gpa);

    if (arr.ty() != .char) return m.throw(.type);

    const fb = file_open_path_u32(m, arr.char_slice()) catch return m.throw(.os);
    defer m.gpa.free(fb);

    const view = std.unicode.Utf8View.init(fb) catch return m.throw(.os);
    var iter = view.iterator();

    // TODO: so much allocating and copying... cries....
    var chars: std.ArrayList(u32) = .empty;
    defer chars.deinit(m.gpa);

    while (iter.nextCodepoint()) |cp| {
        chars.append(m.gpa, cp) catch return m.throw(.oom);
    }

    const len: i64 = @intCast(chars.items.len);
    const ret = sbl.Array.init(m.gpa, &.{len}, .char) catch return m.throw(.oom);
    @memcpy(ret.char_slice(), chars.items);

    m.push(.array(ret));
}

fn frb(m: M) void {
    const x = m.pop();
    if (x.atom()) return m.throw(.type);

    const arr = x.into(.array);
    defer arr.release(m.gpa);

    if (arr.ty() != .char) return m.throw(.type);

    const fb = file_open_path_u32(m, arr.char_slice()) catch return m.throw(.os);
    defer m.gpa.free(fb);

    const len: i64 = @intCast(fb.len);
    const ret = sbl.Array.init(m.gpa, &.{len}, .byte) catch return m.throw(.oom);
    @memcpy(ret.byte_slice(), fb);

    m.push(.array(ret));
}

fn debug_array(m: M) void {
    const x = m.top().*;
    if (x.atom()) return m.throw(.type);
    const arr = x.into(.array);
    std.debug.print("type: {s}\nrefc: {d}\n", .{ @tagName(arr.ty()), arr.refc() });
}

fn file_open_path_u32(m: M, path_u32: []const u32) ![]const u8 {
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    var i: usize = 0;
    for (path_u32) |cp| {
        const c: u21 = @intCast(cp);
        i += try std.unicode.utf8Encode(c, path_buf[i..]);
    }

    const path = path_buf[0..i];
    const cwd = std.Io.Dir.cwd();
    const bytes = try cwd.readFileAlloc(m.io, path, m.gpa, .limited(10 * 1024 * 1024));
    return bytes;
}

const M = *sbl.Machine;
const Stack_Effect = sbl.bc.StackEffect;

const std = @import("std");
const sbl = @import("sbl");
