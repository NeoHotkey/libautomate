const builtin = @import("builtin");

pub const InputEvent = @import("InputEvent.zig").InputEvent;

const backend = switch (builtin.target.os.tag) {
    .linux => @import("linux/hid.zig"),
    .windows => @import("windows/hid.zig"),
    .macos => @import("macos/hid.zig"),
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
