pub const fmt = @import("fmt.zig");

test {
    @import("std").testing.refAllDecls(@This());
}