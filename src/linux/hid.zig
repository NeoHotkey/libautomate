const std = @import("std");
const Input = @import("../Input.zig").Input;
const InputEvent = @import("../InputEvent.zig").InputEvent;
const c = @cImport({
    @cInclude("linux/uinput.h");
    @cInclude("wayland-client.h");
    @cInclude("xkbcommon/xkbcommon.h");
    @cInclude("X11/Xlib.h");
    @cInclude("virtual-keyboard-unstable-v1-client-protocol.h");
    @cInclude("input-method-unstable-v2-client-protocol.h");
});

var uinput: ?UinputConnection = null;
var wayland: ?WaylandConnection = null;

// TODO: These fallbacks need to be redone with logging added. It's currently very unclear what is being used and why.
pub fn init() !void {
    sw: switch (DisplayManager.wayland) {
        .wayland => {
            wayland = WaylandConnection.init() catch |e| switch (e) {
                error.CouldNotConnectToDisplay => continue :sw .x,
                else => return e,
            };
        },
        .x => {
            // TODO: write X implementation.
            continue :sw .unknown;
        },
        .unknown => {
            uinput = try UinputConnection.init();
        },
    }
}

pub fn deinit() void {
    if (uinput) |it| it.deinit();
    if (wayland) |it| it.deinit();
}

pub fn sendEvent(event: InputEvent) !void {
    if (wayland) |it| {
        try it.sendEvent(event);
    } else if (uinput) |it| {
        try it.sendEvent(event);
    }
}

pub fn typeCharacter(char: u21) !void {
    if (wayland) |it| {
        try it.typeCharacter(char);
    } else if (uinput) |it| {
        try it.typeCharacter(char);
    }
}

const UinputConnection = struct {
    file: std.fs.File,
    start_time: i64,

    pub fn init() !UinputConnection {
        const file = try std.fs.openFileAbsolute("/dev/uinput", .{ .mode = .write_only });

        try ioctl(file, c.UI_SET_EVBIT, c.EV_KEY);

        for (c.KEY_ESC..c.KEY_MAX) |key| try ioctl(file, c.UI_SET_KEYBIT, key);

        const setup: c.uinput_setup = .{
            .name = zeroPadded(80, "libautomate virtual input device"),
            .id = .{
                .bustype = c.BUS_VIRTUAL,
                .vendor = 0xC7A0,
                .product = 0x0000,
            },
        };

        try ioctl(file, c.UI_DEV_SETUP, &setup);
        try ioctl(file, c.UI_DEV_CREATE, undefined);

        return .{
            .file = file,
            .start_time = std.time.milliTimestamp(),
        };
    }

    pub fn deinit(this: UinputConnection) void {
        try ioctl(this.file, c.UI_DEV_DESTROY, undefined);
        this.file.close();
    }

    pub fn sendEvent(this: UinputConnection, event: InputEvent) !void {
        if (event.is_down) {
            try this.press(event.input);
        } else {
            try this.release(event.input);
        }
        try this.report();
    }

    pub fn typeCharacter(this: UinputConnection, char: u21) !void {
        _ = this;
        _ = char;
        return error.NotImplementedYet;
    }

    // TODO: Improve/diversify error handling and improve error messages.
    fn ioctl(file: std.fs.File, request: u32, arg: anytype) !void {
        const result = if (@TypeOf(arg) == @TypeOf(undefined)) c.ioctl(file.handle, request) else c.ioctl(file.handle, request, arg);
        switch (std.posix.errno(result)) {
            .SUCCESS => return,
            else => |e| return std.posix.unexpectedErrno(e),
        }
    }

    fn press(this: UinputConnection, input: Input) !void {
        try this.emit(c.EV_KEY, inputToKeycode(input), 1);
    }

    fn release(this: UinputConnection, input: Input) !void {
        try this.emit(c.EV_KEY, inputToKeycode(input), 0);
    }

    fn report(this: UinputConnection) !void {
        try this.emit(c.EV_SYN, c.SYN_REPORT, 0);
    }

    fn emit(this: UinputConnection, event_type: c_ushort, code: c_ushort, value: c_int) !void {
        this.waitUntilReady();

        const event: c.struct_input_event = .{
            .type = event_type,
            .code = code,
            .value = value,
        };

        try this.file.writeAll(&@as([@sizeOf(c.struct_input_event)]u8, @bitCast(event)));
    }

    // Sleep until we can be (reasonably) sure that our inputs will go through.
    // This is a stupid hack to account for the time it takes userspace to register the device, during which events are dropped silently.
    // TODO: Investigate if device registration can be queried cleanly instead.
    // See https://www.kernel.org/doc/html/v6.9/input/uinput.html?highlight=sleep#keyboard-events
    fn waitUntilReady(this: UinputConnection) void {
        const duration = this.start_time + 250 - std.time.milliTimestamp();
        if (duration < 0) return;
        std.Thread.sleep(@intCast(duration * std.time.ns_per_ms));
    }

    fn zeroPadded(comptime length: usize, comptime source: []const u8) [length]u8 {
        std.debug.assert(length >= source.len);

        var buf: [length]u8 = std.mem.zeroes([length]u8);
        @memcpy(buf[0..source.len], source);
        return buf;
    }

    fn inputToKeycode(input: Input) c_ushort {
        return switch (input) {
            .a => c.KEY_A,
            .b => c.KEY_B,
            .c => c.KEY_C,
            .d => c.KEY_D,
            .e => c.KEY_E,
            .f => c.KEY_F,
            .g => c.KEY_G,
            .h => c.KEY_H,
            .i => c.KEY_I,
            .j => c.KEY_J,
            .k => c.KEY_K,
            .l => c.KEY_L,
            .m => c.KEY_M,
            .n => c.KEY_N,
            .o => c.KEY_O,
            .p => c.KEY_P,
            .q => c.KEY_Q,
            .r => c.KEY_R,
            .s => c.KEY_S,
            .t => c.KEY_T,
            .u => c.KEY_U,
            .v => c.KEY_V,
            .w => c.KEY_W,
            .x => c.KEY_X,
            .y => c.KEY_Y,
            .z => c.KEY_Z,
            .zero => c.KEY_0,
            .one => c.KEY_1,
            .two => c.KEY_2,
            .three => c.KEY_3,
            .four => c.KEY_4,
            .five => c.KEY_5,
            .six => c.KEY_6,
            .seven => c.KEY_7,
            .eight => c.KEY_8,
            .nine => c.KEY_9,
        };
    }
};

// TODO: Refactor. This struct has too many reponsibilities.
const WaylandConnection = struct {
    display: *c.wl_display,
    registry: *c.wl_registry,
    seat: ?*c.wl_seat = null,
    keyboard_manager: ?*c.zwp_virtual_keyboard_manager_v1 = null,
    keyboard: ?*c.zwp_virtual_keyboard_v1 = null,
    input_method_manager: ?*c.zwp_input_method_manager_v2 = null,
    input_method: ?*c.zwp_input_method_v2 = null,

    pub fn init() !WaylandConnection {
        const display = c.wl_display_connect(null) orelse return error.CouldNotConnectToDisplay;
        const registry = c.wl_display_get_registry(display) orelse return error.CouldNotGetRegistry;

        var this: @This() = .{ .display = display, .registry = registry };

        if (c.wl_registry_add_listener(registry, &registry_listener, &this) < 0) return error.CouldNotRegister;
        if (c.wl_display_dispatch(this.display) < 0) return error.CouldNotDispatch;
        if (c.wl_display_roundtrip(this.display) < 0) return error.CouldNotRoundtrip;

        if (this.seat == null) return error.NoSeat;
        if (this.keyboard_manager) |keyboard_manager| {
            this.keyboard = c.zwp_virtual_keyboard_manager_v1_create_virtual_keyboard(keyboard_manager, this.seat) orelse return error.CouldNotCreateVirtualKeyboard;
        }
        if (this.input_method_manager) |input_method_manager| {
            this.input_method = c.zwp_input_method_manager_v2_get_input_method(input_method_manager, this.seat) orelse return error.CouldNotCreateInputMethod;
        }

        return this;
    }

    pub fn deinit(this: @This()) void {
        if (this.input_method) |it| c.zwp_input_method_v2_destroy(it);
        if (this.input_method_manager) |it| c.zwp_input_method_manager_v2_destroy(it);
        if (this.keyboard) |it| c.zwp_virtual_keyboard_v1_destroy(it);
        if (this.keyboard_manager) |it| c.zwp_virtual_keyboard_manager_v1_destroy(it);
        if (this.seat) |it| c.wl_seat_destroy(it);
        c.wl_registry_destroy(this.registry);
        c.wl_display_disconnect(this.display);
    }

    pub fn sendEvent(this: @This(), event: InputEvent) !void {
        _ = this;
        _ = event;
    }

    pub fn typeCharacter(this: @This(), char: u21) !void {
        const keycode = charToKeycode(char);
        std.log.debug("Going to send keycode {?d}.", .{keycode});
        if (this.keyboard != null) std.log.debug("Keyboard is active.", .{});
        if (this.input_method != null) std.log.debug("Input Method is active.", .{});
    }

    const registry_listener: c.wl_registry_listener = .{
        .global = &handleWaylandEvent,
        .global_remove = null, // not needed.
    };

    fn handleWaylandEvent(data: ?*anyopaque, reg: ?*c.wl_registry, name: u32, interface: [*c]const u8, version: u32) callconv(.c) void {
        const this: *@This() = @ptrCast(@alignCast(data.?));

        const interface_name = std.mem.span(interface);

        // TODO: this iterates over both strings twice. Could be optimized.
        if (std.mem.eql(u8, interface_name, std.mem.span(c.wl_seat_interface.name))) {
            this.seat = @ptrCast(@alignCast(c.wl_registry_bind(reg, name, &c.wl_seat_interface, @min(version, 7))));
        } else if (std.mem.eql(u8, interface_name, std.mem.span(c.zwp_virtual_keyboard_manager_v1_interface.name))) {
            this.keyboard_manager = @ptrCast(@alignCast(c.wl_registry_bind(reg, name, &c.zwp_virtual_keyboard_manager_v1_interface, 1)));
        } else if (std.mem.eql(u8, interface_name, std.mem.span(c.zwp_input_method_manager_v2_interface.name))) {
            this.input_method_manager = @ptrCast(@alignCast(c.wl_registry_bind(reg, name, &c.zwp_input_method_manager_v2_interface, 1)));
        }
    }

    fn charToKeycode(char: u21) ?c.xkb_keysym_t {
        const keysym = c.xkb_utf32_to_keysym(char);
        if (keysym == c.XKB_KEY_NoSymbol) return null;
        return keysym;
    }
};

const DisplayManager = enum {
    unknown,
    x,
    wayland,
};
