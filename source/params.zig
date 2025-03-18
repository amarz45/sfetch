const std = @import("std");
const global = @import("global.zig");
const util = @import("util.zig");

pub const Icon_type = enum {
    large,
    small,
};

pub const Id = std.BoundedArray(u8, 16);

const Param = enum {
    help,
    icon,
    icon_type,
    //print_icon_default,
    //print_icon,

    const map: std.StaticStringMap(Param) = .initComptime(.{
        .{"help",               .help              },
        .{"icon",               .icon              },
        .{"icon-type",          .icon_type         },
        //.{"print-icon-default", .print_icon_default},
        //.{"print-icon",         .print_icon        },
    });

    fn get(param: []const u8) ! Param {
        success: {
            if (param[0] != '-')
                break :success;

            return map.get(param[1..]) orelse
                break :success;

        }

        try util.perrorf(
            "unknown parameter ‘{s}’. Try ‘-help’ for usage instructions.",
            .{param}, 1
        );
    }
};

pub fn parse(writer: anytype) ! Icon_type {
    var icon_type: Icon_type = .large;
    var iter: std.process.ArgIterator = .init();

    // If there’s more than one parameter (the program name), loop through the
    // parameters.
    if (iter.skip())
    while (iter.next()) |param| switch (try Param.get(param)) {
        .help =>
            try help(),
        .icon =>
            try writer.print("{s}", .{try next_param(&iter)}),
        .icon_type => {
            const next = try next_param(&iter);
            icon_type = if (std.mem.eql(u8, next, "large"))
                .large
            else if (std.mem.eql(u8, next, "small"))
                .small
            else
                try util.perrorf(
                    "-icon-type: invalid argument ‘{s}’." ++
                    "Expected ‘large’ or ‘small’.", .{next}, 1
                );
        },
        //.print_icon_default =>
        //.print_icon =>
    };

    return icon_type;
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
            "icon-type",
            "Specifies the icon type. Can be ‘large’ or ‘small’.",
        },
        //.{
            //"print-icon-default",
            //"Print only the (default) icon.",
        //},
        //.{
            //"print-icon",
            //"Print only the icon for the specified operating system.",
        //},
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
