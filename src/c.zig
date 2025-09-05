//! All C imports in one Zig module.

pub usingnamespace @cImport({
    @cInclude("linux/uinput.h");
    @cInclude("wayland-client.h");
    @cInclude("X11/Xlib.h");
    @cInclude("virtual-keyboard-unstable-v1-client-protocol.h");
});
