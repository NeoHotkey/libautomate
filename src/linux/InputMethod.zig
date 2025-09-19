const std = @import("std");
const log = @import("log");
const wl = @import("wayland").client.wl;
const zwp = @import("wayland").client.zwp;
const Wayland = @import("Wayland.zig").Wayland;

pub const InputMethod = struct {
    wayland: Wayland,
    input_method: *zwp.InputMethodV2,
    state: *State,

    pub const State = enum(u32) {
        unavailable = 0,
        inactive = 1,
        _,

        pub const initial: State = .inactive;

        pub fn activate(this: *State) void {
            this.* = @enumFromInt(2);
        }

        pub fn getSerial(this: State) u32 {
            std.debug.assert(this != .unavailable and this != .inactive);

            return @intFromEnum(this) - 2;
        }

        pub fn incrSerial(this: *State) void {
            std.debug.assert(this.* != .unavailable and this.* != .inactive);

            this.* = @enumFromInt(@intFromEnum(this.*) + 1);
        }

        pub fn format(this: State, _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
            switch (this) {
                .unavailable => try writer.writeAll("unavailable"),
                .inactive => try writer.writeAll("inactive"),
                else => try std.fmt.format(writer, "serial({d})", .{this.getSerial()}),
            }
        }
    };

    pub fn init(wayland: Wayland, state: *State) !InputMethod {
        log.enter(@src());
        defer log.exit();

        const seat = try wayland.register(wl.Seat, wl.Seat.interface, 7);
        defer seat.destroy();

        const manager = try wayland.register(zwp.InputMethodManagerV2, zwp.InputMethodManagerV2.interface, 1);
        defer manager.destroy();

        const this: InputMethod = .{
            .wayland = wayland,
            .input_method = try manager.getInputMethod(seat),
            .state = state,
        };

        this.input_method.setListener(*State, handleInputMethodEvent, state);
        log.debug(@src(), "Input Method listener set.", .{});

        try this.waitUntilActive();

        try wayland.roundtrip();

        return this;
    }

    pub fn deinit(this: InputMethod) void {
        log.enter(@src());
        defer log.exit();

        this.input_method.destroy();
    }

    pub fn typeCharacter(this: InputMethod, char: u21) !void {
        log.enter(@src());
        defer log.exit();

        var string: [4:0]u8 = [4:0]u8{ 0, 0, 0, 0 };
        const len = try std.unicode.wtf8Encode(char, &string);

        log.debug(@src(), "Char '{u}' == WTF-8 string \"{s}\"", .{ char, string[0..len] });

        try this.typeText(string[0..len :0]);
    }

    pub fn typeText(this: InputMethod, text: [:0]const u8) !void {
        log.enter(@src());
        defer log.exit();

        log.debug(@src(), "State: {any}", .{this.state.*});

        if (this.state.* == .inactive) return;
        if (this.state.* == .unavailable) return error.Unavailable;

        this.input_method.commitString(text);
        this.input_method.commit(this.state.getSerial());

        try this.wayland.roundtrip();
    }

    fn handleInputMethodEvent(_: *zwp.InputMethodV2, event: zwp.InputMethodV2.Event, state: *State) void {
        log.enter(@src());
        defer log.exit();

        log.debug(@src(), "Event: {s}", .{@tagName(event)});

        switch (event) {
            .activate => state.activate(),
            .deactivate => state.* = .inactive,
            .unavailable => state.* = .unavailable,
            .done => state.incrSerial(),
            else => {},
        }
    }

    fn waitUntilActive(this: InputMethod) !void {
        log.enter(@src());
        defer log.exit();

        while (this.state.* == .inactive) {
            log.debug(@src(), "Current state: {any}", .{this.state.*});

            try this.wayland.dispatch();
        }

        log.debug(@src(), "Final state: {any}", .{this.state});

        if (this.state.* == .unavailable) {
            return error.Unavailable;
        }
    }
};
