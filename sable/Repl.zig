r: Readline,

const prefix = "sbl0.0$ ";

const help_index =
    \\?  help
    \\?k keymap
    \\?p primitives
;

const help_keymap =
    \\  ‿ `strand'
    \\[ ← `assign'
    \\f λ `function'
    \\i ι `iota'
    \\l ⧻ `length'
    \\o ⫦ `over'
    \\O ⊪ `rotate'
    \\p □ `peek'
    \\r △ `order up'
    \\R ▽ `order down'
    \\s ρ `shape'
    \\S Ρ `reshape'
    \\+ × `mul'
    \\- ÷ `div'
    \\1 ´ `fold'
;

const help_primitives =
    \\nyi
;

pub fn keymap(c: u8) ?u21 {
    return switch (c) {
        // syntax
        'f' => 'λ',
        '[' => '←',
        ' ' => '‿',
        // primitives
        'i' => 'ι',
        'l' => '⧻',
        'o' => '⫦',
        'O' => '⊪',
        'p' => '□',
        'r' => '△',
        'R' => '▽',
        's' => 'ρ',
        'S' => 'Ρ',
        '+' => '×',
        '-' => '÷',
        // modifiers
        '1' => '´',
        else => null,
    };
}

pub fn init() Repl {
    return .{
        .r = Readline{},
    };
}

pub fn run(self: *Repl) !void {
    while (true) {
        const line = self.r.read_line(prefix) catch |e| switch (e) {
            error.Eof => break,
            error.Interrupted => break,
            else => return e,
        };
        if (line.len > 0 and line[0] == '?') {
            self.help(line);
            continue;
        }
        self.r.write_bytes(line);
        self.r.write_bytes("\r\n");
    }
}

fn help(self: *Repl, str: []const u8) void {
    if (str.len <= 1) {
        self.r.write_bytes(help_index);
    } else switch (str[1]) {
        'k' => self.r.write_bytes(help_keymap),
        'p' => self.r.write_bytes(help_primitives),
        else => self.r.write_bytes(help_index),
    }
    self.r.write_bytes("\r\n\r\n");
}

const Repl = @This();

const std = @import("std");
const sbl = @import("sbl");
const Readline = sbl.Readline;
