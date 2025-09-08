const builtin = @import("builtin");

const linux = @import("hid.linux.zig");
const windows = @import("hid.windows.zig");
const macos = @import("hid.macos.zig");

pub const InputEvent = @import("InputEvent.zig").InputEvent;

const backend = switch (builtin.target.os.tag) {
    .linux => linux,
    .windows => windows,
    .macos => macos,
    else => @compileError("Target unsupported."),
};

pub fn init() !void {
    return backend.init();
}

pub fn deinit() void {
    backend.deinit();
}

pub fn sendEvent(event: InputEvent) !void {
    return backend.sendEvent(event);
}

pub fn typeCharacter(char: u21) !void {
    return backend.typeCharacter(char);
}
