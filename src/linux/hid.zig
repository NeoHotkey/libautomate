const std = @import("std");
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

pub fn init() !void {
    if (try initWayland()) return;
    if (try initX()) return;

    return error.NoSuitableBackendFound;
}

pub fn deinit() void {}

pub fn sendEvent(event: InputEvent) !void {
    _ = event;
    return error.NotYetImplemented;
}

pub fn typeCharacter(char: u21) !void {
    switch (backend) {
        .none => unreachable,
        .wayland_virtual_keyboard => |it| try it.typeCharacter(char),
        .wayland_input_method => |it| try it.typeCharacter(char),
    }
}

fn initWayland() !bool {
    const wayland = Wayland.init() catch return false;

    if (try initWaylandInputMethod(&wayland)) return true;
    if (try initWaylandVirtualKeyboard(&wayland)) return true;

    return false;
}

fn initWaylandInputMethod(wayland: *const Wayland) !bool {
    backend = .{
        .wayland_input_method = InputMethod.init(wayland) catch |e| switch (e) {
            error.ProtocolUnsupported => return false,
            else => return e,
        },
    };

    return true;
}

fn initWaylandVirtualKeyboard(wayland: *const Wayland) !bool {
    backend = .{
        .wayland_virtual_keyboard = VirtualKeyboard.init(wayland) catch |e| switch (e) {
            error.ProtocolUnsupported => return false,
            else => return e,
        },
    };

    return true;
}

fn initX() !bool {
    return false;
}
