const std = @import("std");
const units = @import("units.zig");

const expectEqualStrings = std.testing.expectEqualStrings;

pub const percent_len = "100 %".len;
pub const memory_len = "1024 KiB".len;
pub const time_len = "999 d 23 h 59 m 59 s".len;

// Given a buffer and the memory amount in kibibytes, write to the buffer a
// string with the amount in a human-readable format with the appropriate unit.
pub fn memory(buf: []u8, num: units.Mib(f32)) ! []const u8 {
    @setFloatMode(.optimized);

    const mem,
    const unit: *const [3]u8 = mem: {
        if (num.v < 1 << 10) {
            @branchHint(.unlikely);
            break :mem .{num.v, "MiB"};
        }
        break :mem .{num.v / (1 << 10), "GiB"};
    };

    return ram(buf, mem, unit);
}

pub fn drive(
    buf: []u8,
    bytes: f32,
    comptime check_mib: bool,
) ! []const u8 {
    @setFloatMode(.optimized);

    const mem,
    const unit: *const [3]u8 = mem: {
        if (check_mib and bytes < 1 << 30) {
            @branchHint(.unlikely);
            break :mem .{bytes / (1 << 20), "MiB"};
        }
        if (bytes < 1 << 40)
            break :mem .{bytes / (1 << 30), "GiB"};
        break :mem .{bytes / (1 << 40), "TiB"};
    };

    return ram(buf, mem, unit);
}

fn ram(buf: []u8, mem: f32, unit: *const [3]u8) ! []const u8 {
    return if (mem < 10)
        std.fmt.bufPrint(buf, "{d:.2} {s}", .{mem, unit})
    else if (mem < 100)
        std.fmt.bufPrint(buf, "{d:.1} {s}", .{mem, unit})
    else
        std.fmt.bufPrint(buf, "{d:.0} {s}", .{mem, unit});
}

test memory {
    const _test = struct {
        fn f(_buf: []u8, num: f32, comptime expected: []const u8) ! void {
            try expectEqualStrings(try memory(_buf, num), expected);
        }
    }.f;

    var buf: ["1024 KiB".len]u8 = undefined;

    const one_mib = 1 << 10;
    const one_gib = 1 << 20;

    try _test(&buf, 0, "0.00 MiB");
    try _test(&buf, one_mib, "1.00 MiB");
    try _test(&buf, one_mib * 10, "10.0 MiB");
    try _test(&buf, one_mib * 99, "99.0 MiB");
    try _test(&buf, one_mib * 100, "100 MiB");
    try _test(&buf, one_mib * 1000, "1000 MiB");
    try _test(&buf, one_mib * 1023, "1023 MiB");
    try _test(&buf, one_gib, "1.00 GiB");
}
