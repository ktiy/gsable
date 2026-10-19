const std = @import("std");
const manifest = @import("build.zig.zon");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{
        .preferred_optimize_mode = .ReleaseSmall,
    });

    const options = b.addOptions();
    options.addOption([]const u8, "version", manifest.version);

    const sdl3 = b.dependency("sdl3", .{
        .target = target,
        .optimize = optimize,
        .ext_image = true,
    });
    const known_folders = b.dependency("known_folders", .{ .target = target, .optimize = optimize });

    const imports = [_]std.Build.Module.Import{
        .{ .name = "sdl3", .module = sdl3.module("sdl3") },
        .{ .name = "known_folders", .module = known_folders.module("known-folders") },
    };

    const sable = build_exe(b, "sbl", "sable/main.zig", target, optimize, options, &imports);
    const gui = build_exe(b, "gsable", "gui/main.zig", target, optimize, options, &imports);

    const sable_mod_tests = b.addTest(.{ .root_module = sable });
    const gui_mod_tests = b.addTest(.{ .root_module = gui });

    const run_sable_mod_tests = b.addRunArtifact(sable_mod_tests);
    const run_gui_mod_tests = b.addRunArtifact(gui_mod_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_sable_mod_tests.step);
    test_step.dependOn(&run_gui_mod_tests.step);
}

fn build_exe(
    b: *std.Build,
    comptime name: []const u8,
    src: []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    options: *std.Build.Step.Options,
    imports: []const std.Build.Module.Import,
) *std.Build.Module {
    const module = b.addModule(name, .{
        .root_source_file = b.path(src),
        .target = target,
        .optimize = optimize,
        .imports = imports,
    });

    module.addImport(name, module);
    module.addOptions("build_options", options);

    const exe = b.addExecutable(.{
        .name = name,
        .root_module = module,
    });

    b.installArtifact(exe);

    const build_step = b.step(name, "Build the " ++ name ++ " executable");
    build_step.dependOn(&exe.step);

    const run_step = b.step("run-" ++ name, "Run the " ++ name ++ " executable");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    return module;
}
