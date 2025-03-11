const std = @import("std");
const global = @import("global.zig");
const modules = @import("modules.zig");
const params = @import("params.zig");
const util = @import("util.zig");
const icons = @import("icons.zig");

pub fn main() ! void {
    const entries = [_]modules.Entry {
        .os, .kernel, .uptime, .packages_user, .packages_total, .memory,
        .storage, .battery
    };

    var buf: [256]u8 = undefined;
    const os_info = try modules.get_os_info(&buf);
    const os: modules.Os = try .get(os_info.id);

    const icon_id: modules.Os
    = if (try params.parse()) |str|
        try .get(str)
    else
        os;

    const icon, const spaces = switch (icon_id) {
        .almalinux   => try icons.get("almalinux"),
        .alpine      => try icons.get("alpine"),
        .antix       => try icons.get("antix"),
        .arch        => try icons.get("arch"),
        .archcraft   => try icons.get("archcraft"),
        .archlabs    => try icons.get("archlabs"),
        .arco        => try icons.get("arco"),
        .artix       => try icons.get("artix"),
        .bunsenlabs  => try icons.get("bunsenlabs"),
        .centos      => try icons.get("centos"),
        .debian      => try icons.get("debian"),
        .deepin      => try icons.get("deepin"),
        .devuan      => try icons.get("devuan"),
        .elementary  => try icons.get("elementary"),
        .endeavouros => try icons.get("endeavouros"),
        .fedora      => try icons.get("fedora"),
        .garuda      => try icons.get("garuda"),
        .gentoo      => try icons.get("gentoo"),
        .kali        => try icons.get("kali"),
        .kdeneon     => try icons.get("kdeneon"),
        .manjaro     => try icons.get("manjaro"),
        .mint        => try icons.get("mint"),
        .mx          => try icons.get("mx"),
        .opensuse    => try icons.get("opensuse"),
        .parrot      => try icons.get("parrot"),
        .peppermint  => try icons.get("peppermint"),
        .pop         => try icons.get("pop"),
        .qubes       => try icons.get("qubes"),
        .rhel        => try icons.get("rhel"),
        .rocky       => try icons.get("rocky"),
        .tails       => try icons.get("tails"),
        .trisquel    => try icons.get("trisquel"),
        .ubuntu      => try icons.get("ubuntu"),
        .zorin       => try icons.get("zorin"),
    };

    //var result: std.BoundedArray(u8, 2048) = .{};
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

    try global.stdout.writeAll(result.constSlice());
}
