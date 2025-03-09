const std = @import("std");
const units = @import("units.zig");
const util = @import("util.zig");
const Memory = @This();

total:  units.Mib(f32),
free:   units.Mib(f32),
cached: units.Mib(f32),

const expect = std.testing.expect;
const linux = std.os.linux;

const sysinfo = extern struct {
    uptime:    c_long,
    loads:     [3]c_ulong,
    totalram:  c_ulong,
    freeram:   c_ulong,
    sharedram: c_ulong,
    freeswap:  c_ulong,
    procs:     c_ushort,
    totalhigh: c_ulong,
    freehigh:  c_ulong,
    mem_unit:  c_uint,
    _f:        [20 - 2 * @sizeOf(c_long) - @sizeOf(c_int)]c_char,
};

pub fn init() ! Memory {
    @setFloatMode(.optimized);

    var info: sysinfo = undefined;
    if (linux.syscall1(.sysinfo, @intFromPtr(&info)) != 0)
        try util.perror("sysinfo: syscall failed.", 1);

    const total_bytes: f32 = @floatFromInt(info.totalram);
    const free_bytes: f32 = @floatFromInt(info.freeram);
    const cached_kib = try get_cached();

    return .{
        .total  = .from_bytes(.{.v = total_bytes}),
        .free   = .from_bytes(.{.v = free_bytes}),
        .cached = .from_kib(cached_kib),
    };
}

pub fn get_used(memory: *const Memory) units.Mib(f32) {
    @setFloatMode(.optimized);
    return .{.v = memory.total.v - memory.free.v - memory.cached.v};
}

fn get_cached() ! units.Kib(f32) {
    const entry = "Cached:";

    var file = try std.fs.cwd().openFile("/proc/meminfo", .{});
    defer file.close();

    var buf: [256]u8 = undefined;
    const close_index = try file.pread(&buf, 0);
    const slice = buf[0..close_index];

    a: {
        const slice_index = std.mem.indexOf(u8, slice, entry) orelse
            break :a;

        const slice_no_entry = buf[(slice_index + entry.len)..];
        const slice_no_spaces = std.mem.trimLeft(u8, slice_no_entry, " ");

        const unit_index = std.mem.indexOfScalar(u8, slice_no_spaces, 'k')
        orelse break :a;

        const slice_num = slice_no_spaces[0..(unit_index - " ".len)];

        return .{.v = try std.fmt.parseFloat(f32, slice_num)};
    }

    try util.parse_failure("/proc/meminfo");
}

test "memory" {
    const memory: Memory = try .init();

    try expect(memory.total >= 0);
    try expect(memory.free >= 0);
    try expect(memory.buffers >= 0);
    try expect(memory.cached >= 0);
}
