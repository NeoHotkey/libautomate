const std = @import("std");
const c = @import("c.zig").defs;

pub const Wayland = struct {
    display: *c.wl_display,

    pub fn init() !Wayland {
        return Wayland{
            .display = c.wl_display_connect(null) orelse return error.FailedToConnect,
        };
    }

    pub fn deinit(this: Wayland) void {
        c.wl_display_disconnect(this.display);
    }

    pub fn register(this: Wayland, Protocol: type, interface: *const c.wl_interface, version: struct { min: u32, max: u32 }) !*Protocol {
        const registry = c.wl_display_get_registry(this.display) orelse return error.FailedToGetRegistry;
        defer c.wl_registry_destroy(registry);

        var request: RegistryRequest = .{
            .interface = interface,
            .min_version = version.min,
            .max_version = version.max,
        };

        if (c.wl_registry_add_listener(registry, &registry_listener, &request) < 0) return error.FailedToRegister;
        // TODO: is dispatch required?
        if (c.wl_display_dispatch(this.display) < 0) return error.FailedDispatch;
        try this.roundtrip();

        if (request.protocol) |result| {
            return @ptrCast(@alignCast(result));
        } else {
            return error.ProtocolUnsupported;
        }
    }

    pub fn roundtrip(this: Wayland) !void {
        if (c.wl_display_roundtrip(this.display) < 0) return error.FailedRoundtrip;
    }

    const registry_listener: c.wl_registry_listener = .{
        .global = &handleGlobal,
    };

    fn handleGlobal(data: ?*anyopaque, registry: ?*c.wl_registry, name: u32, interface_name: [*c]const u8, version: u32) callconv(.c) void {
        const request: *RegistryRequest = @ptrCast(@alignCast(data));

        if (std.mem.eql(u8, std.mem.span(interface_name), std.mem.span(request.interface.name))) {
            request.protocol = c.wl_registry_bind(registry, name, request.interface, @max(@min(version, request.max_version), request.min_version));
        }
    }

    const RegistryRequest = struct {
        interface: *const c.wl_interface,
        min_version: u32,
        max_version: u32,
        protocol: ?*anyopaque = null,
    };
};
