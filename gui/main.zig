const std = @import("std");
const Io = std.Io;

const sbl = @import("sbl");
const sdl = @import("sdl3");

const fps = 60;
const screen_width = 640;
const screen_height = 480;

pub fn main(_: std.process.Init) !void {
    defer sdl.shutdown();

    const init_flags = sdl.InitFlags{ .video = true };
    try sdl.init(init_flags);
    defer sdl.quit(init_flags);

    const w = try sdl.video.Window.init("hello, sdl3", screen_width, screen_height, .{});
    defer w.deinit();

    var fps_cap = sdl.extras.FramerateCapper(f32){ .mode = .{ .limited = fps } };

    var quit = false;
    while (!quit) {
        const dt = fps_cap.delay();
        _ = dt;

        const surface = try w.getSurface();
        try surface.fillRect(null, surface.mapRgb(128, 30, 255));
        try w.updateSurface();

        while (sdl.events.poll()) |event| switch (event) {
            .quit => quit = true,
            .terminating => quit = true,
            else => {},
        };
    }
}
