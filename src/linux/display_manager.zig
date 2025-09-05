const std = @import("std");
const c = @import("../c.zig");

pub var current: DisplayManager = getCurrent();

pub const DisplayManager = enum {
    unknown,
    x,
    wayland,
};

pub fn getCurrent() !DisplayManager {
    if (try isWayland()) return .wayland;
    if (try isX()) return .x;

    return .unknown;
}

fn isWayland() !bool {
    var wayland = try std.DynLib.open("libwayland-client.so");
    defer wayland.close();

    const wl_display_connect = wayland.lookup(*const @TypeOf(c.wl_display_connect), "wl_display_connect") orelse return error.ConnectFunctionNotFound;
    const wl_display_disconnect = wayland.lookup(*const @TypeOf(c.wl_display_disconnect), "wl_display_disconnect") orelse return error.DisconnectFunctionNotFound;

    const display = wl_display_connect(null) orelse return error.CouldNotConnect;
    defer wl_display_disconnect(display);

    return true;
}

fn isX() !bool {
    var x = try std.DynLib.open("libX11.so");
    defer x.close();

    const XOpenDisplay = x.lookup(*const @TypeOf(c.XOpenDisplay), "XOpenDisplay") orelse return error.ConnectFunctionNotFound;
    const XCloseDisplay = x.lookup(*const @TypeOf(c.XCloseDisplay), "XCloseDisplay") orelse return error.DisconnectFunctionNotFound;

    const display = XOpenDisplay(null) orelse return error.CouldNotConnect;
    defer _ = XCloseDisplay(display);

    return true;
}
