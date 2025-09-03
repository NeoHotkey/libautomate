const std = @import("std");
const automate = @import("automate");

pub fn main() !void {
    try automate.init();

    try automate.hid.sendEvent(.{
        .input = .h,
        .is_down = true,
    });
    try automate.hid.sendEvent(.{
        .input = .h,
        .is_down = false,
    });

    std.Thread.sleep(1 * std.time.ns_per_s);

    try automate.hid.sendEvent(.{
        .input = .i,
        .is_down = true,
    });
    try automate.hid.sendEvent(.{
        .input = .i,
        .is_down = false,
    });
}
