const std = @import("std");

pub const hid = @import("hid.zig");

pub fn init() !void {
    try hid.init();
}

pub fn deinit() void {
    hid.deinit();
}
