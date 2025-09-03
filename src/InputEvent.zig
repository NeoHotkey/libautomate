const Input = @import("Input.zig").Input;

pub const InputEvent = packed struct {
    input: Input,
    is_down: bool,
};
