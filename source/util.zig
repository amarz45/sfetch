const std = @import("std");
const global = @import("global.zig");

pub inline fn perrorf(comptime fmt: []const u8, args: anytype, err: u8)
! noreturn {
    try global.stderr.print("Error: "++fmt++"\n", args);
    std.process.exit(err);
}

pub inline fn perror(comptime msg: []const u8, err: u8) ! noreturn {
    try global.stderr.writeAll("Error: "++msg++"\n");
    std.process.exit(err);
}

pub inline fn parse_failure(comptime filename: []const u8) ! noreturn {
    try perror(filename++": failed to parse.", 1);
}
