const std = @import("std");
const automate = @import("automate");

pub fn main() !void {
    try automate.init();
    defer automate.deinit();

    try automate.hid.typeText("Hello, 世界!");
}
