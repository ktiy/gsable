const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const sdl3 = b.dependency("sdl3", .{
        .target = target,
        .optimize = optimize,
    });

    const sable_module = b.addModule("sbl", .{
        .root_source_file = b.path("sable/main.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "sdl3", .module = sdl3.module("sdl3") },
        },
    });
    const sable_exe = b.addExecutable(.{
        .name = "sable",
        .root_module = sable_module,
    });

    const gui_module = b.addModule("gui", .{
        .root_source_file = b.path("gui/main.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "sdl3", .module = sdl3.module("sdl3") },
            .{ .name = "sable", .module = sable_module },
        },
    });
    const gui_exe = b.addExecutable(.{
        .name = "gsable",
        .root_module = gui_module,
    });

    b.installArtifact(sable_exe);
    b.installArtifact(gui_exe);

    const sable_run_step = b.step("sable", "Run the sable binary");
    const gui_run_step = b.step("gui", "Run the gsable binary");

    const sable_run_cmd = b.addRunArtifact(sable_exe);
    const gui_run_cmd = b.addRunArtifact(gui_exe);

    sable_run_step.dependOn(&sable_run_cmd.step);
    gui_run_step.dependOn(&gui_run_cmd.step);

    sable_run_cmd.step.dependOn(b.getInstallStep());
    gui_run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        sable_run_cmd.addArgs(args);
        gui_run_cmd.addArgs(args);
    }

    const sable_mod_tests = b.addTest(.{
        .root_module = sable_module,
    });
    const gui_mod_tests = b.addTest(.{
        .root_module = gui_module,
    });

    const run_sable_mod_tests = b.addRunArtifact(sable_mod_tests);
    const run_gui_mod_tests = b.addRunArtifact(gui_mod_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_sable_mod_tests.step);
    test_step.dependOn(&run_gui_mod_tests.step);
}
