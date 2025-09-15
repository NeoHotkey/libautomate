const std = @import("std");
const wl = @import("wayland").client.wl;
const zwp = @import("wayland").client.zwp;
const Wayland = @import("Wayland.zig").Wayland;

pub const InputMethod = struct {
    wayland: *const Wayland,
    input_method: *zwp.InputMethodV2,

    pub fn init(wayland: *const Wayland) !InputMethod {
        const seat = try wayland.register(wl.Seat, wl.Seat.interface, 7);
        defer seat.destroy();

        const manager = try wayland.register(zwp.InputMethodManagerV2, zwp.InputMethodManagerV2.interface, 1);
        defer manager.destroy();

        return InputMethod{
            .wayland = wayland,
            .input_method = try manager.getInputMethod(seat),
        };
    }

    pub fn deinit(this: InputMethod) void {
        this.input_method.destroy();
    }

    pub fn typeCharacter(this: InputMethod, char: u21) !void {
        var string: [4:0]u8 = [4:0]u8{ 0, 0, 0, 0 };
        const len = try std.unicode.wtf8Encode(char, &string);

        this.input_method.commitString(@ptrCast(string[0..len]));
        this.input_method.commit(0);
    }
};
