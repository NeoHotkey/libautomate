const std = @import("std");
const c = @import("c.zig").defs;
const Wayland = @import("Wayland.zig").Wayland;

pub const InputMethod = struct {
    wayland: *const Wayland,
    input_method: *c.zwp_input_method_v2,

    pub fn init(wayland: *const Wayland) !InputMethod {
        const seat = try wayland.register(c.wl_seat, &c.wl_seat_interface, .{ .min = 1, .max = 7 });
        defer c.wl_seat_destroy(seat);

        const manager = try wayland.register(c.zwp_input_method_manager_v2, &c.zwp_input_method_manager_v2_interface, .{ .min = 1, .max = 1 });
        defer c.zwp_input_method_manager_v2_destroy(manager);

        return InputMethod{
            .wayland = wayland,
            .input_method = c.zwp_input_method_manager_v2_get_input_method(manager, seat) orelse return error.FailedToGetInputMethod,
        };
    }

    pub fn deinit(this: InputMethod) void {
        c.zwp_input_method_v2_destroy(this.input_method);
    }

    pub fn typeCharacter(this: InputMethod, char: u21) !void {
        var string: [5]u8 = "\x00" ** 5;
        const len = try std.unicode.wtf8Encode(char, &string);

        c.zwp_input_method_v2_commit_string(this.input_method, string[0..len].ptr);
        c.zwp_input_method_v2_commit(this.input_method, 0);
    }
};
