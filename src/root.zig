const std = @import("std");
const log = @import("log");

pub const hid = @import("hid.zig");

pub fn init() !void {
    log.enter(@src());
    defer log.exit();

    try hid.init();
}

pub fn deinit() void {
    log.enter(@src());
    defer log.exit();

    hid.deinit();
}
