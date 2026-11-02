in: posix.fd_t = std.posix.STDIN_FILENO,
out: posix.fd_t = std.posix.STDOUT_FILENO,

buf: [line_size]u8 = undefined,
len: usize = 0,

pub const line_size = 4096;

pub fn read_line(self: *Readline, prompt: []const u8) ![:0]const u8 {
    self.len = 0;

    const old = self.raw_mode() catch |e| {
        if (e == error.NotATerminal) {
            self.write_bytes(prompt);
            return self.read_bytes();
        }
        return e;
    };

    defer posix.tcsetattr(self.in, .FLUSH, old) catch {};

    self.write_bytes(prompt);

    var state: enum { start, backslash } = .start;
    while (true) {
        const c = try self.read_byte();
        switch (c) {
            '\r', '\n' => {
                self.write_bytes("\r\n");
                self.buf[self.len] = 0;
                return @ptrCast(self.buf[0..self.len]);
            },
            3 => {
                // ^C
                self.write_bytes("^C\r\n");
                return error.Interrupted;
            },
            4 => {
                // ^D
                if (self.len == 0) {
                    self.write_bytes("\r\n");
                    return error.Eof;
                }
            },
            127, 8 => {
                // backspace
                if (self.len > 0) {
                    self.len -= 1;
                    while (self.len >= 0 and (self.buf[self.len] & 0xc0) == 0x80) {
                        self.len -= 1;
                    }
                    self.write_bytes("\x08 \x08");
                }
            },
            '\\' => {
                state = .backslash;
            },
            else => {
                if (state == .backslash) {
                    if (Repl.keymap(c)) |d| {
                        const len = try std.unicode.utf8Encode(d, self.buf[self.len..]);
                        self.write_bytes(self.buf[self.len..][0..len]);
                        self.len += len;
                    } else {
                        self.buf[self.len] = '\\';
                        self.len += 1;
                        self.write_bytes("\\");
                    }
                    state = .start;
                    continue;
                }
                if (c >= 32 and self.len < self.buf.len) {
                    self.buf[self.len] = c;
                    self.len += 1;
                    self.write_bytes(&[_]u8{c});
                }
            },
        }
    }
}

fn read_byte(self: *Readline) !u8 {
    var buf: [1]u8 = undefined;
    if (try posix.read(self.in, &buf) == 0) {
        return error.Eof;
    }
    return buf[0];
}

fn read_bytes(self: *Readline) ![:0]const u8 {
    while (true) {
        const c = self.read_byte() catch |e| {
            if (e == error.Eof and self.len > 0) break;
            return e;
        };
        if (c == '\n') break;
        if (self.len < self.buf.len) {
            self.buf[self.len] = c;
            self.len += 1;
        }
    }
    self.buf[self.len] = 0;
    return @ptrCast(self.buf[0..self.len]);
}

pub fn write_bytes(self: *Readline, bytes: []const u8) void {
    var off = @as(usize, 0);
    while (off < bytes.len) {
        off += linux.write(self.out, bytes[off..].ptr, bytes.len - off);
    }
}

fn raw_mode(self: *Readline) !posix.termios {
    const old = try posix.tcgetattr(self.in);
    var raw = old;
    raw.lflag.ECHO = false;
    raw.lflag.ICANON = false;
    raw.lflag.ISIG = false;
    raw.iflag.ICRNL = false;
    raw.cc[@backingInt(posix.V.MIN)] = 1;
    raw.cc[@backingInt(posix.V.TIME)] = 0;
    try posix.tcsetattr(self.in, .FLUSH, raw);
    return old;
}

pub const Readline = @This();
const std = @import("std");
const sbl = @import("sbl");
const Repl = sbl.Repl;
const linux = std.os.linux; // todo: support for other os
const posix = std.posix;
