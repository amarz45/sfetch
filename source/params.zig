const std = @import("std");
const global = @import("global.zig");
const util = @import("util.zig");

const Param = enum {
    help,
    icon,
    print_icon_default,
    print_icon,

    const map: std.StaticStringMap(Param) = .initComptime(.{
        .{"-help",               .help              },
        .{"-icon",               .icon              },
        .{"-print-icon-default", .print_icon_default},
        .{"-print-icon",         .print_icon        },
    });

    fn get(param: anytype) Param {
        return map.get(param) orelse
            std.process.exit(1);
    }
};

pub fn parse() ! ?[]const u8 {
    var os_id: ?[]const u8 = null;
    var iter: std.process.ArgIterator = .init();

    // If there’s more than one parameter (the program name), loop through the
    // parameters.
    if (iter.skip())
    while (iter.next()) |param| switch (Param.get(param)) {
        .help =>
            try help(),
        .icon =>
            os_id = try next_param(&iter),
        .print_icon_default =>
            try global.stdout.writeAll("default icon\n"),
        .print_icon => {
            try global.stdout.print("{s}\n", .{try next_param(&iter)});
        },
    };

    return os_id;
}

fn help() ! noreturn {
    comptime var msg: []const u8 =
        \\Sfetch: Fast command-line system information utility
        \\
        \\Parameters:
        \\
    ;

    inline for (.{
        .{
            "help",
            "Print this help message and exit.",
        },
        .{
            "icon",
            "Use the specified operating system for the icon instead of the "
            ++ "detected one.",
        },
        .{
            "print-icon-default",
            "Print only the (default) icon.",
        },
        .{
            "print-icon",
            "Print only the icon for the specified operating system.",
        },
    })
    |table|
        msg = msg ++ "    " ++ bold("-"++table[0]) ++ "  " ++ table[1] ++ "\n";

    try global.stdout.writeAll(msg);
    std.process.exit(0);
}

inline fn bold(str: []const u8) []const u8 {
    return "\x1b[1m"++str++"\x1b[0m";
}

inline fn next_param(iter: *std.process.ArgIterator) ! []const u8 {
    return iter.next() orelse
        try util.perror("-print-icon: missing argument.", 1);
}
