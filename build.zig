const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const mod = b.addModule("root", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const static_lib = b.addLibrary(.{
        .linkage = .static,
        .name = "automate",
        .root_module = mod,
    });

    const dynamic_lib = b.addLibrary(.{
        .linkage = .dynamic,
        .name = "automate",
        .root_module = mod,
    });

    b.installArtifact(static_lib);
    b.installArtifact(dynamic_lib);

    mod.addIncludePath(addWaylandProtocol(b, "virtual-keyboard-unstable-v1").dirname());

    const example_exe = b.addExecutable(.{
        .name = "example",
        .root_source_file = b.path("example/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    example_exe.root_module.addImport("automate", mod);

    b.installArtifact(example_exe);

    const example_run = b.addRunArtifact(example_exe);
    const example_step = b.step("run-example", "Run example project");
    example_step.dependOn(&example_run.step);

    const unit_tests = b.addTest(.{
        .root_module = mod,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}

fn addWaylandProtocol(b: *std.Build, comptime name: []const u8) std.Build.LazyPath {
    const generate = b.addSystemCommand(&.{ "wayland-scanner", "client-header" });

    generate.addFileArg(b.path("wayland-protocols/" ++ name ++ ".xml"));
    return generate.addOutputFileArg(name ++ "-client-protocol.h");
}
