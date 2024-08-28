const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zig-io",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.linkLibC();
    exe.addSystemIncludePath(std.Build.LazyPath{ .cwd_relative = "/usr/include" });
    exe.linkSystemLibrary("tiff");
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addTest(.{
        .root_source_file = b.path("zig-io.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_tests.linkLibC();
    exe.addSystemIncludePath(std.Build.LazyPath{ .cwd_relative = "/usr/include" });
    exe_tests.linkSystemLibrary("tiff");
    const uts = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&uts.step);
}
