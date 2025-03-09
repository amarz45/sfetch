const std = @import("std");
const modules = @import("modules.zig");
const util = @import("util.zig");
const icons = @import("icons.zig");

const stdout = std.io.getStdOut().writer();

pub fn main() ! void {
    const entries = [_]modules.Entry {
        .os, .kernel, .uptime, .packages_user, .packages_total, .memory,
        .storage, .battery
    };

    var buf: [256]u8 = undefined;
    const os_info = try modules.get_os_info(&buf);

    const os: modules.Os = try .get(os_info.id);

    const icon, const spaces = switch (os) {
        .alpine   => try icons.get("alpine"),
        .arch     => try icons.get("arch"),
        .centos   => try icons.get("centos"),
        .debian   => try icons.get("debian"),
        .fedora   => try icons.get("fedora"),
        .gentoo   => try icons.get("gentoo"),
        .kali     => try icons.get("kali"),
        .manjaro  => try icons.get("manjaro"),
        .opensuse => try icons.get("opensuse"),
        .ubuntu   => try icons.get("ubuntu"),
    };

    var result: std.BoundedArray(u8, 2048) = .{};

    {var i: u8 = 0;
    while (true) : (i += 1) {
        const icon_fmt = "\x1b[34m{s}\x1b[0m"; // blue
        const sep = " "**4;
        const writer = result.writer();

        if (i < entries.len) {
            const entry = try entries[i].string(&buf, os, os_info.name);

            if (i < icon.len and entries[i] != .blank) {
                //= Print the icon and the module.
                const icon_line = icon.get(i).constSlice();
                try writer.print(icon_fmt++sep++"{s}\n", .{icon_line, entry});
            }
            else
                //= Print only the module.
                try writer.print("{s}"++sep++"{s}\n", .{spaces, entry});
        }
        else if (i < icon.len) {
            //= Print only the icon.
            const icon_line = icon.get(i).constSlice();
            try writer.print(icon_fmt++"\n", .{icon_line});
        }
        else break;
    }}

    try stdout.writeAll(result.constSlice());
}
