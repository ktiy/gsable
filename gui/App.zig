io: std.Io,
gpa: std.mem.Allocator,
arena: std.heap.ArenaAllocator,
tmp: std.heap.ArenaAllocator,
env: std.process.Environ.Map,

init_flags: sdl.InitFlags,
window: sdl.video.Window,
renderer: sdl.render.Renderer,
fps_cap: sdl.extras.FramerateCapper(f32),

font: sdl.ttf.Font,

quit: bool,

const fps = 60;
const screen_width = 640;
const screen_height = 480;

const col = struct {
    pub const white: Colour = .{ .r = 255, .g = 255, .b = 255, .a = 255 };
    pub const black: Colour = .{ .r = 0, .g = 0, .b = 0, .a = 255 };
};

pub fn init(
    self: *App,
    process: std.process.Init.Minimal,
    io: std.Io,
    gpa: std.mem.Allocator,
    arena: std.heap.ArenaAllocator,
    tmp: std.heap.ArenaAllocator,
) !void {
    self.arena = arena;
    const env = try process.environ.createMap(self.arena.allocator());

    try sdl.setAppMetadata("sable", "0.0.1", "org.piapiac.kitty.sable");

    const flags: sdl.InitFlags = .{ .video = true };
    try sdl.init(flags);
    try sdl.ttf.init();

    const window, const renderer = try sdl.render.Renderer.initWithWindow(
        "sable",
        screen_width,
        screen_height,
        .{ .resizable = true },
    );

    self.* = .{
        .io = io,
        .gpa = gpa,
        .arena = arena,
        .tmp = tmp,
        .env = env,
        .init_flags = flags,
        .window = window,
        .renderer = renderer,
        .fps_cap = .{ .mode = .{ .limited = fps } },
        .font = undefined,
        .quit = false,
    };

    try self.set_app_icon();
    self.font = try .init(try self.get_dir_path(.data, "sable/fairfax-hd/FairfaxHD.ttf"), 24);
}

pub fn deinit(self: *App) void {
    self.window.deinit();
    self.renderer.deinit();
    self.font.deinit();
    sdl.shutdown();
}

pub fn frame(self: *App) !bool {
    if (self.quit) return false;

    const dt = self.fps_cap.delay();
    _ = dt;

    try self.renderer.setDrawColor(col.white.toSdl());
    try self.renderer.renderFillRect(null);

    try self.draw_text("sable", 16, 16);

    return true;
}

pub fn frame_end(self: *App) !void {
    try self.renderer.present();
}

pub fn draw_text(self: *App, str: []const u8, x: f32, y: f32) !void {
    const surf = try self.font.renderTextBlended(str, col.black);
    defer surf.deinit();

    const tex = try self.renderer.createTextureFromSurface(surf);
    defer tex.deinit();

    const w, const h = try tex.getSize();
    const dst: sdl.rect.FRect = .{ .x = x, .y = y, .w = w, .h = h };
    try self.renderer.renderTexture(tex, null, dst);
}

fn set_app_icon(self: *App) !void {
    const data_dir = try self.open_dir(.data);
    const sbl_data_dir = try data_dir.openDir(self.io, "sable", .{});
    const icon_file = try sbl_data_dir.readFileAlloc(self.io, "icon.png", self.gpa, .unlimited);
    defer self.gpa.free(icon_file);

    const icon = try sdl.image.loadPngIo(try .initFromConstMem(icon_file));
    defer icon.deinit();

    try self.window.setIcon(icon);
}

fn open_dir(self: *App, dir: folders.KnownFolder) !std.Io.Dir {
    return try folders.open(self.io, self.tmp.allocator(), &self.env, dir, .{}) orelse {
        return std.Io.File.OpenError.FileNotFound;
    };
}

fn get_dir_path(self: *App, dir: folders.KnownFolder, path: []const u8) ![:0]const u8 {
    const base = try folders.getPath(self.io, self.tmp.allocator(), &self.env, dir) orelse {
        return std.Io.File.OpenError.FileNotFound;
    };
    const full = try std.mem.concatWithSentinel(self.tmp.allocator(), u8, &.{ base, "/", path }, 0);
    return full;
}

const Colour = sdl.ttf.Color;

const App = @This();
const folders = @import("known_folders");
const sdl = @import("sdl3");
const std = @import("std");
