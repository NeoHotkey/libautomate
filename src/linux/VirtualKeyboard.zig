const std = @import("std");
const log = @import("log");
const wl = @import("wayland").client.wl;
const zwp = @import("wayland").client.zwp;
const Wayland = @import("Wayland.zig").Wayland;
const c = @cImport({
    @cInclude("xkbcommon/xkbcommon.h");
});

pub const VirtualKeyboard = struct {
    wayland: *const Wayland,
    keyboard: *zwp.VirtualKeyboardV1,

    pub fn init(wayland: *const Wayland) !VirtualKeyboard {
        log.enter(@src());
        defer log.exit();

        const seat = try wayland.register(wl.Seat, wl.Seat.interface, 7);
        defer seat.destroy();

        const manager = try wayland.register(zwp.VirtualKeyboardManagerV1, zwp.VirtualKeyboardManagerV1.interface, 1);
        defer manager.destroy();

        return VirtualKeyboard{
            .wayland = wayland,
            .keyboard = try manager.createVirtualKeyboard(seat),
        };
    }

    pub fn deinit(this: VirtualKeyboard) void {
        log.enter(@src());
        defer log.exit();

        this.keyboard.destroy();
    }

    pub fn typeCharacter(this: VirtualKeyboard, char: u21) !void {
        log.enter(@src());
        defer log.exit();

        const keycode = charToKeycode(char) orelse return error.KeycodeNotFound;

        this.keyboard.key(0, keycode, @intFromEnum(wl.Keyboard.KeyState.pressed));
        try this.wayland.roundtrip();

        this.keyboard.key(0, keycode, @intFromEnum(wl.Keyboard.KeyState.released));
        try this.wayland.roundtrip();
    }

    fn charToKeycode(char: u21) ?c.xkb_keysym_t {
        log.enter(@src());
        defer log.exit();

        const keysym = c.xkb_utf32_to_keysym(char);
        if (keysym == c.XKB_KEY_NoSymbol) return null;
        return keysym;
    }
};
