const App = @This();

const fps = 60;
const screen_width = 640;
const screen_height = 480;

const std = @import("std");
const sdl = @import("sdl3");
const folders = @import("known_folders");

quit: bool,
debug_allocator: std.heap.DebugAllocator(.{}),
arena: std.heap.ArenaAllocator,
gpa: std.mem.Allocator,
tmp: std.mem.Allocator,
io: std.Io,
init_flags: sdl.InitFlags,
window: sdl.video.Window,
renderer: sdl.render.Renderer,
fps_cap: sdl.extras.FramerateCapper(f32),

pub fn init(g: *App, io: std.Io) !void {
    g.io = io;
    g.debug_allocator = .{};
    g.arena = .init(std.heap.page_allocator);
    g.gpa = g.debug_allocator.allocator();
    g.tmp = g.arena.allocator();

    try sdl.setAppMetadata("sable", "0.0.1", "org.piapiac.kitty.sable");

    g.init_flags = .{ .video = true };
    try sdl.init(g.init_flags);

    g.window, g.renderer = try sdl.render.Renderer.initWithWindow(
        "sable",
        screen_width,
        screen_height,
        .{ .resizable = true },
    );

    g.fps_cap = .{ .mode = .{ .limited = fps } };
    g.quit = false;
}

pub fn deinit(g: *App) void {
    g.window.deinit();
    g.renderer.deinit();
    sdl.shutdown();
    g.arena.deinit();
    _ = g.debug_allocator.deinit();
}

pub fn frame(g: *App) !bool {
    if (g.quit) return false;

    const dt = g.fps_cap.delay();
    _ = dt;

    try g.renderer.setDrawColor(.{.r=255, .g=255, .b=255, .a=255});
    try g.renderer.renderFillRect(null);

    return true;
}

pub fn frame_end(g: *App) !void {
    try g.renderer.present();
}
