const std = @import("std");
const global = @import("global.zig");
const modules = @import("modules.zig");
const params = @import("params.zig");
const util = @import("util.zig");
const Icon = @import("Icon.zig");

pub fn main() ! void {
    const entries = [_]modules.Entry {
        .os, .kernel, .uptime, .packages_user, .packages_total, .memory,
        .storage, .battery
    };

    var buf: [256]u8 = undefined;
    const os_info = try modules.get_os_info(&buf);
    const os: modules.Os = try .get(os_info.id);

    var icon_id_param: params.Id = .{};
    const icon_type = try params.parse(icon_id_param.writer());

    const icon_id: modules.Os
    = if (icon_id_param.len == 0)
        try .get(os_info.id)
    else
        try .get(icon_id_param.constSlice());

    const icon = try get_icon(icon_type, icon_id, os_info.name);
    var result: std.BoundedArray(u8, 2048) = .{};

    {var i: u8 = 0;
    while (true) : (i += 1) {
        const icon_fmt = "\x1b[34m{s}\x1b[0m"; // blue
        const sep = " "**4;
        const writer = result.writer();

        if (i < entries.len) {
            const entry = try entries[i].string(&buf, os, os_info.name);

            if (i < icon.lines.len and entries[i] != .blank) {
                //= Print the icon and the module.
                const icon_line = icon.lines.get(i).constSlice();
                try writer.print(icon_fmt++sep++"{s}\n", .{icon_line, entry});
            }
            else {
                //= Print only the module.
                const spaces = icon.spaces_padding;
                try writer.print("{s}"++sep++"{s}\n", .{spaces, entry});
            }
        }
        else if (i < icon.lines.len) {
            //= Print only the icon.
            const icon_line = icon.lines.get(i).constSlice();
            try writer.print(icon_fmt++"\n", .{icon_line});
        }
        else break;
    }}

    try global.stdout.writeAll(result.constSlice());
}

fn get_icon(
    icon_type: params.Icon_type,
    icon_id: modules.Os,
    os_name: []const u8
)
! Icon {
    return switch(icon_type) {
        .large => switch (icon_id) {
            .almalinux   => try .get("almalinux"),
            .alpine      => try .get("alpine"),
            .antix       => try .get("antix"),
            .arch        => try .get("arch"),
            .archcraft   => try .get("archcraft"),
            .archlabs    => try .get("archlabs"),
            .arco        => try .get("arco"),
            .artix       => try .get("artix"),
            .bunsenlabs  => try .get("bunsenlabs"),
            .centos      => try .get("centos"),
            .debian      => try .get("debian"),
            .deepin      => try .get("deepin"),
            .devuan      => try .get("devuan"),
            .elementary  => try .get("elementary"),
            .endeavouros => try .get("endeavouros"),
            .fedora      => try .get("fedora"),
            .garuda      => try .get("garuda"),
            .gentoo      => try .get("gentoo"),
            .kali        => try .get("kali"),
            .kdeneon     => try .get("kdeneon"),
            .manjaro     => try .get("manjaro"),
            .mint        => try .get("mint"),
            .mx          => try .get("mx"),
            .opensuse    => try .get("opensuse"),
            .parrot      => try .get("parrot"),
            .peppermint  => try .get("peppermint"),
            .pop         => try .get("pop"),
            .qubes       => try .get("qubes"),
            .rhel        => try .get("rhel"),
            .rocky       => try .get("rocky"),
            .tails       => try .get("tails"),
            .trisquel    => try .get("trisquel"),
            .ubuntu      => try .get("ubuntu"),
            .zorin       => try .get("zorin"),
        },
        .small => switch (icon_id) {
            .alpine      => try .get("alpine_small"),
            .arch        => try .get("arch_small"),
            .arco        => try .get("arco_small"),
            .artix       => try .get("artix_small"),
            .centos      => try .get("centos_small"),
            .debian      => try .get("debian_small"),
            .devuan      => try .get("devuan_small"),
            .elementary  => try .get("elementary_small"),
            .endeavouros => try .get("endeavouros_small"),
            .fedora      => try .get("fedora_small"),
            .garuda      => try .get("garuda_small"),
            .gentoo      => try .get("gentoo_small"),
            .kali        => try .get("kali_small"),
            .manjaro     => try .get("manjaro_small"),
            .mint        => try .get("mint_small"),
            .mx          => try .get("mx_small"),
            .opensuse    => try .get("opensuse_small"),
            .pop         => try .get("pop_small"),
            .rocky       => try .get("rocky_small"),
            .ubuntu      => try .get("ubuntu_small"),

            .almalinux, .antix, .archcraft, .archlabs, .bunsenlabs, .deepin,
            .kdeneon, .parrot, .peppermint, .qubes, .rhel, .tails, .trisquel,
            .zorin
            => try util.perrorf(
                "No small icon variant for operating system ‘{s}’.", .{os_name},
                1
            ),
        },
    };
}
