pub const defs = @cImport({
    @cInclude("wayland-client.h");
    @cInclude("input-method-unstable-v2-client-protocol.h");
    @cInclude("virtual-keyboard-unstable-v1-client-protocol.h");
    @cInclude("xkbcommon/xkbcommon.h");
});
