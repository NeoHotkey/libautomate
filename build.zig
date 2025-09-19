const std = @import("std");
const wayland = @import("wayland");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const log_mod = b.createModule(.{
        .root_source_file = b.path("src/log.zig"),
        .target = target,
        .optimize = optimize,
    });

    const root_mod = b.addModule("root", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    root_mod.addImport("log", log_mod);

    root_mod.linkSystemLibrary("wayland-client", .{});
    root_mod.linkSystemLibrary("X11", .{});
    root_mod.linkSystemLibrary("xkbcommon", .{});

    const scanner: *wayland.Scanner = .create(b, .{});
    root_mod.addImport("wayland", b.createModule(.{ .root_source_file = scanner.result }));

    scanner.addCustomProtocol(b.path("wayland-protocols/virtual-keyboard-unstable-v1.xml"));
    scanner.addCustomProtocol(b.path("wayland-protocols/input-method-unstable-v2.xml"));

    scanner.generate("wl_seat", 7);
    scanner.generate("zwp_virtual_keyboard_manager_v1", 1);
    scanner.generate("zwp_input_method_manager_v2", 1);

    const static_lib = b.addLibrary(.{
        .linkage = .static,
        .name = "automate",
        .root_module = root_mod,
    });

    const dynamic_lib = b.addLibrary(.{
        .linkage = .dynamic,
        .name = "automate",
        .root_module = root_mod,
    });

    b.installArtifact(static_lib);
    b.installArtifact(dynamic_lib);

    addWaylandProtocol(root_mod, "virtual-keyboard-unstable-v1");
    addWaylandProtocol(root_mod, "input-method-unstable-v2");

    const example_exe = b.addExecutable(.{
        .name = "example",
        .root_source_file = b.path("example/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    example_exe.root_module.addImport("automate", root_mod);

    b.installArtifact(example_exe);

    const example_run = b.addRunArtifact(example_exe);
    const example_step = b.step("run-example", "Run example project");
    example_step.dependOn(&example_run.step);

    const unit_tests = b.addTest(.{
        .root_module = root_mod,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}

fn addWaylandProtocol(mod: *std.Build.Module, comptime name: []const u8) void {
    const b = mod.owner;

    const generate_header = b.addSystemCommand(&.{ "wayland-scanner", "client-header" });
    generate_header.addFileArg(b.path("wayland-protocols/" ++ name ++ ".xml"));
    const header = generate_header.addOutputFileArg(name ++ "-client-protocol.h");

    const generate_source = b.addSystemCommand(&.{ "wayland-scanner", "private-code" });
    generate_source.addFileArg(b.path("wayland-protocols/" ++ name ++ ".xml"));
    const source = generate_source.addOutputFileArg(name ++ "-client-protocol.c");

    mod.addIncludePath(header.dirname());
    mod.addCSourceFile(.{ .file = source, .language = .c });
}
