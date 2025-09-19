const std = @import("std");
const builtin = @import("builtin");
const Level = std.log.Level;

pub const enable_tracing = switch (builtin.mode) {
    .Debug => true,
    else => false,
};

pub var level: ?Level = switch (builtin.mode) {
    .Debug => .debug,
    .ReleaseSafe => .info,
    .ReleaseFast, .ReleaseSmall => .warn,
};

pub var writer: std.io.AnyWriter = std.io.getStdErr().writer().any();

pub fn enter(comptime src: std.builtin.SourceLocation) void {
    if (comptime !enable_tracing) return;

    indent(writer);
    std.fmt.format(writer, "[trace] {s} {{\n", .{Location.from(src).fmt()}) catch {};

    indent_size += 1;
}

pub fn exit() void {
    if (comptime !enable_tracing) return;

    indent_size -= 1;

    indent(writer);
    std.fmt.format(writer, "}}\n", .{}) catch {};
}

pub fn debug(comptime src: std.builtin.SourceLocation, comptime fmt: []const u8, args: anytype) void {
    log(.debug, .from(src), fmt, args);
}

pub fn info(comptime src: std.builtin.SourceLocation, comptime fmt: []const u8, args: anytype) void {
    log(.info, .from(src), fmt, args);
}

pub fn warn(comptime src: std.builtin.SourceLocation, comptime fmt: []const u8, args: anytype) void {
    log(.warn, .from(src), fmt, args);
}

pub fn err(comptime src: std.builtin.SourceLocation, comptime fmt: []const u8, args: anytype) void {
    log(.err, .from(src), fmt, args);
}

fn log(comptime lvl: Level, comptime loc: Location, comptime fmt: []const u8, args: anytype) void {
    if (level == null or @intFromEnum(lvl) < @intFromEnum(level.?)) return;

    indent(writer);

    std.fmt.format(writer, "[{s}] {s}: " ++ fmt ++ "\n", .{ @tagName(lvl), loc.fmt() } ++ args) catch {};
}

const Location = struct {
    module: []const u8,
    file: []const u8,
    function: []const u8,

    pub fn fmt(this: Location) []const u8 {
        return std.fmt.allocPrint(alloc, "{[module]s} > {[file]s} > {[function]s}", this) catch @panic("OOM");
    }

    pub fn from(comptime src: std.builtin.SourceLocation) Location {
        return .{
            .module = src.module,
            .file = src.file,
            .function = src.fn_name,
        };
    }
};

const alloc = std.heap.page_allocator;
var indent_size: usize = 0;

fn indent(w: std.io.AnyWriter) void {
    w.writeBytesNTimes("│ ", indent_size -| 1) catch {};
    if (indent_size > 0) w.writeAll("├╴") catch {};
}
