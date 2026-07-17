const std = @import("std");

const sbl = @import("sbl");
const sdl = @import("sdl3");

pub const App = @import("App.zig");
const io = std.Io.Threaded.global_single_threaded.io();
const page_allocator = std.heap.page_allocator;

pub fn main(process: std.process.Init.Minimal) !void {
    var debug_allocator = std.heap.DebugAllocator(.{}){};
    defer _ = debug_allocator.deinit();

    var arena = std.heap.ArenaAllocator.init(page_allocator);
    defer arena.deinit();

    var tmp = std.heap.ArenaAllocator.init(page_allocator);
    defer tmp.deinit();

    const gpa = debug_allocator.allocator();

    var app: App = undefined;
    try app.init(process, io, gpa, arena, tmp);
    defer app.deinit();

    while (try app.frame()) : (try app.frame_end()) {
        while (sdl.events.poll()) |event| switch (event) {
            .quit => app.quit = true,
            .terminating => app.quit = true,
            else => {},
        };
    }
}
