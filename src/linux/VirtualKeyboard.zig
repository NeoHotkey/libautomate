const std = @import("std");
const log = @import("log");
const wl = @import("wayland").client.wl;
const zwp = @import("wayland").client.zwp;
const Wayland = @import("Wayland.zig").Wayland;
const c = @cImport({
    @cInclude("xkbcommon/xkbcommon.h");
});

pub const VirtualKeyboard = struct {
    wayland: Wayland,
    keyboard: *zwp.VirtualKeyboardV1,

    pub fn init(wayland: Wayland) !VirtualKeyboard {
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

        log.debug(@src(), "Pressing down key.", .{});
        this.keyboard.key(0, keycode, @intFromEnum(wl.Keyboard.KeyState.pressed));
        try this.wayland.roundtrip();

        log.debug(@src(), "Releasing key.", .{});
        this.keyboard.key(0, keycode, @intFromEnum(wl.Keyboard.KeyState.released));
        try this.wayland.roundtrip();
    }

    pub fn typeText(this: VirtualKeyboard, text: []const u8) !void {
        var iter = (try std.unicode.Utf8View.init(text)).iterator();

        while (iter.nextCodepoint()) |char| {
            try this.typeCharacter(char);
        }
    }

    fn charToKeycode(char: u21) ?c.xkb_keysym_t {
        log.enter(@src());
        defer log.exit();

        const keysym = c.xkb_utf32_to_keysym(char);
        if (keysym == c.XKB_KEY_NoSymbol) {
            log.debug(@src(), "Char '{u}' does not have an associated keysym.", .{char});
            return null;
        }

        const name = blk: {
            var b: [128]u8 = undefined;
            const len = c.xkb_keysym_get_name(keysym, &b, b.len);
            break :blk b[0..@intCast(len)];
        };

        log.debug(@src(), "Char '{u}' == XKB_KEY_{s} == {d}", .{ char, name, keysym });

        return keysym;
    }
};
