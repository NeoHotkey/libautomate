const std = @import("std");
const log = @import("log");
const wl = @import("wayland").client.wl;

pub const Wayland = struct {
    display: *wl.Display,

    pub fn init() !Wayland {
        log.enter(@src());
        defer log.exit();

        return Wayland{
            .display = try wl.Display.connect(null),
        };
    }

    pub fn deinit(this: Wayland) void {
        log.enter(@src());
        defer log.exit();

        this.display.disconnect();
    }

    pub fn register(this: Wayland, Protocol: type, interface: *const wl.Interface, max_version: u32) !*Protocol {
        log.enter(@src());
        defer log.exit();

        const registry = try this.display.getRegistry();
        defer registry.destroy();
        log.debug(@src(), "Got registry", .{});

        var request: RegistryRequest(Protocol) = .{
            .interface = interface,
            .max_version = max_version,
        };

        registry.setListener(*RegistryRequest(Protocol), getHandler(Protocol), &request);
        log.debug(@src(), "Event listener set.", .{});
        try this.roundtrip();

        if (request.protocol) |proto| {
            return proto;
        } else {
            return error.ProtocolUnsupported;
        }
    }

    pub fn dispatch(this: Wayland) !void {
        log.enter(@src());
        defer log.exit();

        switch (this.display.dispatch()) {
            .SUCCESS => return,
            else => return error.DispatchFailed,
        }
    }

    pub fn roundtrip(this: Wayland) !void {
        log.enter(@src());
        defer log.exit();

        switch (this.display.roundtrip()) {
            .SUCCESS => return,
            else => return error.RoundtripFailed,
        }
    }

    fn getHandler(Protocol: type) *const fn (registry: *wl.Registry, event: wl.Registry.Event, data: *RegistryRequest(Protocol)) void {
        log.enter(@src());
        defer log.exit();

        return struct {
            pub fn handleRegistryEvent(registry: *wl.Registry, event: wl.Registry.Event, request: *RegistryRequest(Protocol)) void {
                switch (event) {
                    .global => |ev| {
                        if (std.mem.eql(u8, std.mem.span(ev.interface), std.mem.span(request.interface.name))) {
                            request.protocol = registry.bind(ev.name, Protocol, @min(request.max_version, ev.version)) catch null;
                        }
                    },
                    else => {},
                }
            }
        }.handleRegistryEvent;
    }

    fn RegistryRequest(Protocol: type) type {
        return struct {
            interface: *const wl.Interface,
            max_version: u32,
            protocol: ?*Protocol = null,
        };
    }
};
