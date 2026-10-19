const Repl = @This();

const std = @import("std");
const sbl = @import("sbl");
const Readline = sbl.Readline;

r: Readline,

const prefix = "sbl0.0$ ";

pub fn init() Repl {
    return .{
        .r = Readline{},
    };
}

pub fn run(self: *Repl) !void {
    while (true) {
        const line = self.r.read_line(prefix) catch |e| {
            if (e == error.Eof) break;
            return e;
        };
        self.r.write_bytes(line);
        self.r.write_bytes("\r\n");
    }
}
