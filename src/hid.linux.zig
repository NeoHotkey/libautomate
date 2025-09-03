const std = @import("std");
const uinput = @cImport(
    @cInclude("linux/uinput.h"),
);
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

        _ = uinput.ioctl(file.handle, uinput.UI_SET_EVBIT, uinput.EV_KEY);

        for (uinput.KEY_ESC..uinput.KEY_KPDOT) |key| { // TODO: KEY_KPDOT is a temporary upper bound, we should explicitly declare which keys are to be enabled instead of iterating over enum values.
            _ = uinput.ioctl(file.handle, uinput.UI_SET_KEYBIT, key);
        }
        const setup: uinput.struct_uinput_setup = .{
            .name = zeroPadded(80, "libautomate virtual input device"),
            .id = .{
                .bustype = uinput.BUS_USB,
                .vendor = 0x1234,
                .product = 0x5678,
            },
        };

        _ = uinput.ioctl(file.handle, uinput.UI_DEV_SETUP, &setup);
        _ = uinput.ioctl(file.handle, uinput.UI_DEV_CREATE);

        return .{
            .file = file,
            .timer = std.time.Timer.start() catch unreachable, // TODO: fallback when timer not available?
        };
    }

    pub fn deinit(this: UinputConnection) void {
        uinput.ioctl(this.file.handle, uinput.UI_DEV_DESTROY);
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

    fn press(this: *UinputConnection, input: Input) !void {
        try this.emit(uinput.EV_KEY, inputToKeycode(input), 1);
    }

    fn release(this: *UinputConnection, input: Input) !void {
        try this.emit(uinput.EV_KEY, inputToKeycode(input), 0);
    }

    fn report(this: *UinputConnection) !void {
        try this.emit(uinput.EV_SYN, uinput.SYN_REPORT, 0);
    }

    fn emit(this: *UinputConnection, event_type: c_ushort, code: c_ushort, value: c_int) !void {
        this.waitUntilReady();

        const event: uinput.struct_input_event = .{
            .type = event_type,
            .code = code,
            .value = value,
            .time = undefined, // field seems to be ignored entirely.
        };

        try this.file.writeAll(&@as([@sizeOf(uinput.struct_input_event)]u8, @bitCast(event)));
    }

    // Sleep 10ms at a time until it's been 1 second since init.
    // This is a stupid hack to account for the time it takes userspace to register the device, during which events are dropped silently.
    // TODO: Investigate if device registration can be queried cleanly instead.
    // See https://www.kernel.org/doc/html/v6.9/input/uinput.html?highlight=sleep#keyboard-events
    fn waitUntilReady(this: *UinputConnection) void {
        while (this.timer.read() < 1 * std.time.ns_per_s) {
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
        .a => uinput.KEY_A,
        .b => uinput.KEY_B,
        .c => uinput.KEY_C,
        .d => uinput.KEY_D,
        .e => uinput.KEY_E,
        .f => uinput.KEY_F,
        .g => uinput.KEY_G,
        .h => uinput.KEY_H,
        .i => uinput.KEY_I,
        .j => uinput.KEY_J,
        .k => uinput.KEY_K,
        .l => uinput.KEY_L,
        .m => uinput.KEY_M,
        .n => uinput.KEY_N,
        .o => uinput.KEY_O,
        .p => uinput.KEY_P,
        .q => uinput.KEY_Q,
        .r => uinput.KEY_R,
        .s => uinput.KEY_S,
        .t => uinput.KEY_T,
        .u => uinput.KEY_U,
        .v => uinput.KEY_V,
        .w => uinput.KEY_W,
        .x => uinput.KEY_X,
        .y => uinput.KEY_Y,
        .z => uinput.KEY_Z,
        .zero => uinput.KEY_0,
        .one => uinput.KEY_1,
        .two => uinput.KEY_2,
        .three => uinput.KEY_3,
        .four => uinput.KEY_4,
        .five => uinput.KEY_5,
        .six => uinput.KEY_6,
        .seven => uinput.KEY_7,
        .eight => uinput.KEY_8,
        .nine => uinput.KEY_9,
    };
}
