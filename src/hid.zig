const builtin = @import("builtin");
const log = @import("log");

pub const InputEvent = @import("InputEvent.zig").InputEvent;

const backend = switch (builtin.target.os.tag) {
    .linux => @import("linux/hid.zig"),
    .windows => @import("windows/hid.zig"),
    .macos => @import("macos/hid.zig"),
    else => @compileError("Target unsupported."),
};

pub fn init() !void {
    log.enter(@src());
    defer log.exit();

    return backend.init();
}

pub fn deinit() void {
    log.enter(@src());
    defer log.exit();

    backend.deinit();
}

pub fn sendEvent(event: InputEvent) !void {
    log.enter(@src());
    defer log.exit();

    return backend.sendEvent(event);
}

pub fn typeCharacter(char: u21) !void {
    log.enter(@src());
    defer log.exit();

    return backend.typeCharacter(char);
}
