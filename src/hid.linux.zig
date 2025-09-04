const std = @import("std");
const c = @import("c.zig");
const Input = @import("Input.zig").Input;
const InputEvent = @import("InputEvent.zig").InputEvent;

var connection: ?UinputConnection = null;

pub fn init() !void {
    connection = try .init();
}

pub fn deinit() void {
    connection.?.deinit();
}

pub fn sendEvent(event: InputEvent) !void {
    try connection.?.sendEvent(event);
}

const UinputConnection = struct {
    file: std.fs.File,
    timer: std.time.Timer,

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
            .timer = std.time.Timer.start() catch unreachable, // TODO: fallback when timer not available?
        };
    }

    pub fn deinit(this: UinputConnection) void {
        try ioctl(this.file, c.UI_DEV_DESTROY, undefined);
        this.file.close();
    }

    pub fn sendEvent(this: *UinputConnection, event: InputEvent) !void {
        if (event.is_down) {
            try this.press(event.input);
        } else {
            try this.release(event.input);
        }
        try this.report();
    }

    // TODO: Improve/diversify error handling and improve error messages.
    fn ioctl(file: std.fs.File, request: u32, arg: anytype) !void {
        const result = if (@TypeOf(arg) == @TypeOf(undefined)) c.ioctl(file.handle, request) else c.ioctl(file.handle, request, arg);
        switch (std.posix.errno(result)) {
            .SUCCESS => return,
            else => |e| return std.posix.unexpectedErrno(e),
        }
    }

    fn press(this: *UinputConnection, input: Input) !void {
        try this.emit(c.EV_KEY, inputToKeycode(input), 1);
    }

    fn release(this: *UinputConnection, input: Input) !void {
        try this.emit(c.EV_KEY, inputToKeycode(input), 0);
    }

    fn report(this: *UinputConnection) !void {
        try this.emit(c.EV_SYN, c.SYN_REPORT, 0);
    }

    fn emit(this: *UinputConnection, event_type: c_ushort, code: c_ushort, value: c_int) !void {
        this.waitUntilReady();

        const event: c.struct_input_event = .{
            .type = event_type,
            .code = code,
            .value = value,
            .time = undefined, // field seems to be ignored entirely.
        };

        try this.file.writeAll(&@as([@sizeOf(c.struct_input_event)]u8, @bitCast(event)));
    }

    // Spin loop until we can be (reasonably) sure that our inputs will go through.
    // This is a stupid hack to account for the time it takes userspace to register the device, during which events are dropped silently.
    // TODO: Investigate if device registration can be queried cleanly instead.
    // See https://www.kernel.org/doc/html/v6.9/input/uinput.html?highlight=sleep#keyboard-events
    fn waitUntilReady(this: *UinputConnection) void {
        while (this.timer.read() < 250 * std.time.ns_per_ms) { // NOTE: 250ms works well on my machine but may need to be increased for compatibility.
            std.Thread.sleep(10 * std.time.ns_per_ms);
        }
    }
};

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
