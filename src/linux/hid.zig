const std = @import("std");
const log = @import("log");
const Input = @import("../Input.zig").Input;
const InputEvent = @import("../InputEvent.zig").InputEvent;
const Wayland = @import("Wayland.zig").Wayland;
const VirtualKeyboard = @import("VirtualKeyboard.zig").VirtualKeyboard;
const InputMethod = @import("InputMethod.zig").InputMethod;

const Backend = union(enum) {
    none: void,
    wayland_virtual_keyboard: VirtualKeyboard,
    wayland_input_method: InputMethod,
};

var backend: Backend = .{ .none = {} };

/// For mutable state of backends.
var data: [128]u8 = undefined;
var fba: std.heap.FixedBufferAllocator = .init(&data);
const alloc = fba.allocator();

pub fn init() !void {
    log.enter(@src());
    defer log.exit();

    if (try initWayland()) return;
    if (try initX()) return;

    return error.NoSuitableBackendFound;
}

pub fn deinit() void {
    log.enter(@src());
    defer log.exit();
}

pub fn sendEvent(event: InputEvent) !void {
    log.enter(@src());
    defer log.exit();

    _ = event;
    return error.NotYetImplemented;
}

pub fn typeCharacter(char: u21) !void {
    log.enter(@src());
    defer log.exit();

    switch (backend) {
        .none => unreachable,
        .wayland_virtual_keyboard => |it| try it.typeCharacter(char),
        .wayland_input_method => |it| try it.typeCharacter(char),
    }
}

pub fn typeText(text: [:0]const u8) !void {
    log.enter(@src());
    defer log.exit();

    switch (backend) {
        .none => unreachable,
        .wayland_virtual_keyboard => |it| try it.typeText(text),
        .wayland_input_method => |it| try it.typeText(text),
    }
}

fn initWayland() !bool {
    log.enter(@src());
    defer log.exit();

    const wayland = Wayland.init() catch |e| {
        log.info(@src(), "Could not connect to wayland compositor ({any}).", .{e});
        return false;
    };

    if (try initWaylandInputMethod(wayland)) return true;
    if (try initWaylandVirtualKeyboard(wayland)) return true;

    log.err(@src(), "No wayland backend supported by the compositor.", .{});

    return false;
}

fn initWaylandInputMethod(wayland: Wayland) !bool {
    log.enter(@src());
    defer log.exit();

    const state = try alloc.create(InputMethod.State);
    state.* = .initial;

    backend = .{
        .wayland_input_method = InputMethod.init(wayland, state) catch |e| switch (e) {
            error.ProtocolUnsupported => return false,
            else => return e,
        },
    };

    log.debug(@src(), "Using WaylandInputMethod backend", .{});

    return true;
}

fn initWaylandVirtualKeyboard(wayland: Wayland) !bool {
    log.enter(@src());
    defer log.exit();

    backend = .{
        .wayland_virtual_keyboard = VirtualKeyboard.init(wayland) catch |e| switch (e) {
            error.ProtocolUnsupported => return false,
            else => return e,
        },
    };

    log.debug(@src(), "Using WaylandVirtualKeyboard backend", .{});

    return true;
}

fn initX() !bool {
    log.enter(@src());
    defer log.exit();

    return false;
}
