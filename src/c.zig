//! All C imports in one Zig module.

pub usingnamespace @cImport(
    @cInclude("linux/uinput.h"),
);
