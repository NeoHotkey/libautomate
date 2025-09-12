const std = @import("std");
const c = @import("c.zig").defs;
const Wayland = @import("Wayland.zig").Wayland;

pub const VirtualKeyboard = struct {
    wayland: *const Wayland,
    keyboard: *c.zwp_virtual_keyboard_v1,

    pub fn init(wayland: *const Wayland) !VirtualKeyboard {
        const seat = try wayland.register(c.wl_seat, &c.wl_seat_interface, .{ .min = 1, .max = 7 });
        defer c.wl_seat_destroy(seat);

        const manager = try wayland.register(c.zwp_virtual_keyboard_manager_v1, &c.zwp_virtual_keyboard_manager_v1_interface, .{ .min = 1, .max = 1 });
        defer c.zwp_virtual_keyboard_manager_v1_destroy(manager);

        return VirtualKeyboard{
            .wayland = wayland,
            .keyboard = c.zwp_virtual_keyboard_manager_v1_create_virtual_keyboard(manager, seat) orelse return error.FailedToCreateKeyboard,
        };
    }

    pub fn deinit(this: VirtualKeyboard) void {
        c.zwp_virtual_keyboard_v1_destroy(this.keyboard);
    }

    pub fn typeCharacter(this: VirtualKeyboard, char: u21) !void {
        const keycode = charToKeycode(char) orelse return error.KeycodeNotFound;

        c.zwp_virtual_keyboard_v1_key(this.keyboard, 0, keycode, c.WL_KEYBOARD_KEY_STATE_PRESSED);
        try this.wayland.roundtrip();

        c.zwp_virtual_keyboard_v1_key(this.keyboard, 0, keycode, c.WL_KEYBOARD_KEY_STATE_RELEASED);
        try this.wayland.roundtrip();
    }

    fn charToKeycode(char: u21) ?c.xkb_keysym_t {
        const keysym = c.xkb_utf32_to_keysym(char);
        if (keysym == c.XKB_KEY_NoSymbol) return null;
        return keysym;
    }
};
