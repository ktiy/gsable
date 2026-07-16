const std = @import("std");
const Io = std.Io;

const sbl = @import("sbl");
const sdl = @import("sdl3");

pub const App = @import("App.zig");

pub fn main(init: std.process.Init) !void {
    var app: App = undefined;

    try app.init(init.io);
    defer app.deinit();

    while (try app.frame()) : (try app.frame_end()) {
        while (sdl.events.poll()) |event| switch (event) {
            .quit => app.quit = true,
            .terminating => app.quit = true,
            else => {},
        };
    }
}
