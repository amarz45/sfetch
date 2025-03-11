const std = @import("std");

const fmt = @import("fmt.zig");
const global = @import("global.zig");
const packages = @import("packages.zig");
const util = @import("util.zig");
const Memory = @import("Memory.zig");

const cwd = std.fs.cwd();
const linux = std.os.linux;
const utsname = std.posix.system.utsname;

pub const color_set = "\x1b[35m";
pub const color_reset = "\x1b[0m";

const to_uppercase = 32;

pub const Entry = enum {
    blank,
    battery,
    cpu,
    hostname,
    kernel,
    memory,
    os,
    packages_total,
    packages_user,
    storage,
    uptime,

    pub fn string(entry: Entry, buf: []u8, os: Os, os_name: []const u8)
    ! []const u8 {
        const uname = std.posix.uname();

        return switch (entry) {
            .battery        => try get_battery(buf),
            .cpu            => try get_cpu(buf),
            .hostname       => try get_hostname(buf, uname.nodename),
            .kernel         => try get_kernel(buf, uname.sysname, uname.release),
            .memory         => try get_memory(buf),
            .os             => try get_os(buf, os_name),
            .packages_total => try packages.get_total(buf, os),
            .packages_user  => try packages.get_user(buf, os),
            .storage        => try get_storage(buf),
            .uptime         => try get_uptime(buf),
            .blank          => "",
        };
    }
};

pub const Os = enum {
    alpine,
    arch,
    centos,
    debian,
    fedora,
    gentoo,
    kali,
    manjaro,
    opensuse,
    ubuntu,

    const hashmap: std.StaticStringMap(Os) = .initComptime(.{
        .{"alpine",   .alpine  },
        .{"arch",     .arch    },
        .{"centos",   .centos  },
        .{"debian",   .debian  },
        .{"fedora",   .fedora  },
        .{"gentoo",   .gentoo  },
        .{"kali",     .kali    },
        .{"manjaro",  .manjaro },
        .{"opensuse", .opensuse},
        .{"ubuntu",   .ubuntu  },
    });

    pub fn get(id: []const u8) ! Os {
        return hashmap.get(id) orelse
            try util.perrorf("unknown operating system ‘{s}’.", .{id}, 1);
    }
};

const statfs = extern struct {
    f_type:    __fsword_t,
    f_bsize:   __fsword_t,
    f_blocks:  blkcnt_t,
    f_bfree:   blkcnt_t,
    f_bavail:  blkcnt_t,

    f_files:   fsfilcnt_t,
    f_ffree:   fsfilcnt_t,
    f_fsid:    fsid_t,
    f_namelen: __fsword_t,
    f_frsize:  __fsword_t,
    f_flags:   __fsword_t,

    const __fsword_t = isize;
    const blkcnt_t = linux.blkcnt_t;
    const fsfilcnt_t = u64;
    const fsid_t = linux.fsid_t;
};

pub fn get_os_info(buf: []u8) ! struct {id: []const u8, name: []const u8} {
    const file = try cwd.openFile("/etc/os-release", .{});
    const bytes_read = try file.preadAll(buf, 0);
    
    const contents = buf[0..bytes_read];
    var start: usize = 0;

    success: {
        const id = while (std.mem.indexOfScalarPos(u8, contents, start, '\n'))
        |_idx| {
            const key = "ID";
            const idx = _idx + 1;

            if (contents.len < idx + key.len)
                break :success;

            if (std.mem.eql(u8, contents[idx..][0..key.len], key)) {
                const thing = contents[(idx + (key++"=").len)..];
                const newline_i = std.mem.indexOfScalar(u8, thing, '\n') orelse
                    break :success;
                break thing[0..newline_i];
            }

            start = idx;
        }
        else break :success;

        const name = while (std.mem.indexOfScalarPos(u8, contents, start, '\n'))
        |_idx| {
            const key = "PRETTY_NAME";
            const idx = _idx + 1;

            if (contents.len < idx + key.len)
                break :success;

            if (std.mem.eql(u8, contents[idx..][0..key.len], key)) {
                const thing = contents[(idx + (key++"=\"").len)..];
                const quote_i = std.mem.indexOfScalar(u8, thing, '"') orelse
                    break :success;
                break thing[0..quote_i];
            }

            start = idx;
        }
        else break :success;

        return .{.id = id, .name = name};
    }

    try util.parse_failure("/etc/os-release");
}

fn get_battery(buf: []u8) ! []const u8 {
    const battery_dir = try cwd.openDir("/sys/class/power_supply/BAT0", .{});

    const capacity_file = try battery_dir.openFile("capacity", .{});
    const status_file = try battery_dir.openFile("status", .{});

    var capacity_buf: ["100\n".len]u8 = undefined;
    var status_buf: ["Discharging\n".len]u8 = undefined;

    const capacity_bytes_read = try capacity_file.preadAll(&capacity_buf, 0);
    const status_bytes_read = try status_file.preadAll(&status_buf, 0);

    const capacity = switch (capacity_bytes_read) {
        0, 1 => try util.perror("failed to read battery capacity file.", 1),
        else => capacity_buf[0..(capacity_bytes_read - "\n".len)],
    };

    const status = switch (status_bytes_read) {
        0, 1 =>
            try util.perror("failed to read battery status file.", 1),
        else => a: {
            status_buf[0] += to_uppercase;
            break :a status_buf[0..(status_bytes_read - "\n".len)];
        },
    };

    const pfx = color_set++"Battery:"++color_reset++" ";

    return std.fmt.bufPrint(buf, pfx++"{s} % ({s})", .{capacity, status});
}

fn get_cpu(buf: []u8) ! []const u8 {
    a: {
        const file = try cwd.openFile("/proc/cpuinfo", .{});

        var file_buf: [256]u8 = undefined;
        const bytes_read = try file.preadAll(&file_buf, 0);
        const contents = file_buf[0..bytes_read];

        const _start_index = std.mem.indexOf(u8, contents, "model ") orelse
            break :a;
        const start_index = _start_index + "name       : ".len;

        const contents_left = contents[start_index..];
        const end_index = std.mem.indexOfScalar(u8, contents_left, '\n') orelse
            break :a;
        const contents_final = contents_left[0..end_index];

        const pfx = color_set++"CPU:"++color_reset++" ";

        return std.fmt.bufPrint(buf, pfx++"{s}", .{contents_final});
    }

    try util.parse_failure("/proc/cpuinfo");
}

fn get_storage(buf: []u8) ! []const u8 {
    var stat: statfs = undefined;
    if (linux.syscall2(.statfs, @intFromPtr("/"), @intFromPtr(&stat)) != 0)
        try util.perror("statfs: syscall failed.", 1);

    const total_bytes = stat.f_blocks * stat.f_bsize;
    const free_bytes = stat.f_bfree * stat.f_bsize;
    const used_bytes = total_bytes - free_bytes;

    const pfx = color_set++"Storage:"++color_reset++" ";
    const mem_str = "9999 TiB";
    const sep = " / ";

    var total_buf: [mem_str.len]u8 = undefined;
    var used_buf: [mem_str.len]u8 = undefined;

    const total = try fmt.drive(&total_buf, @floatFromInt(total_bytes), false);
    const used = try fmt.drive(&used_buf, @floatFromInt(used_bytes), true);

    return std.fmt.bufPrint(buf, pfx++"{s}"++sep++"{s}", .{used, total});
}

fn get_hostname(buf: []u8, nodename: [64:0]u8) ! []const u8 {
    const pfx = color_set++"Hostname:"++color_reset++" ";

    const null_i = std.mem.indexOfScalar(u8, &nodename, 0).?;
    const hostname = nodename[0..null_i];

    return std.fmt.bufPrint(buf, pfx++"{s}", .{hostname});
}

fn get_kernel(buf: []u8, _sysname: [64:0]u8, _release: [64:0]u8) ! []const u8 {
    const pfx = color_set++"Kernel:"++color_reset++" ";

    const sysname_null_i = std.mem.indexOfScalar(u8, &_sysname, 0).?;
    const release_null_i = std.mem.indexOfScalar(u8, &_release, 0).?;

    const sysname = _sysname[0..sysname_null_i];
    const release = _release[0..release_null_i];

    return std.fmt.bufPrint(buf, pfx++"{s} {s}", .{sysname, release});
}

fn get_memory(buf: []u8) ! []const u8 {
    var memory: Memory = try .init();
    const used = memory.get_used();

    var used_buf: ["1024 KiB".len]u8 = undefined;
    var total_buf: ["1024 KiB".len]u8 = undefined;

    const pfx = color_set++"Memory:"++color_reset++" ";

    const used_str = try fmt.memory(&used_buf, used);
    const total_str = try fmt.memory(&total_buf, memory.total);
    return std.fmt.bufPrint(buf, pfx++"{s} / {s}", .{used_str, total_str});
}

fn get_os(buf: []u8, os: []const u8) ! []const u8 {
    const pfx = color_set++"Operating system:"++color_reset++" ";
    return std.fmt.bufPrint(buf, pfx++"{s}", .{os});
}

fn os_id(os: []const u8) ! []const u8 {
    const space_index = std.mem.indexOfScalar(u8, os, ' ') orelse return os;
    if (space_index == 0) {
        try util.perror("failed to parse operating system.", 1);
    }
    return os[0..space_index];
}

fn get_uptime(buf: []u8) ! []const u8 {
    const pfx = color_set++"Uptime:"++color_reset++" ";

    var file_buf: [32]u8 = undefined;

    const file = try cwd.openFile("/proc/uptime", .{});

    var end_index = try file.pread(&file_buf, 0) - 1;
    if (file_buf[end_index] != '\n') end_index += 1;
    const sep_index = std.mem.indexOfScalar(u8, &file_buf, ' ') orelse
        @panic("/proc/uptime: space not found.");

    const uptime_str = file_buf[0..sep_index];

    const seconds = try std.fmt.parseFloat(f32, uptime_str);

    if (seconds < 60)
        return std.fmt.bufPrint(buf, pfx++"{d} s", .{seconds});

    const minutes = @trunc(seconds / 60);
    const seconds_rem = @trunc(seconds - minutes * 60);

    if (minutes < 60)
        return std.fmt.bufPrint(
            buf, pfx++"{d} m {d} s", .{minutes, seconds_rem}
        );

    const hours = @trunc(minutes / 60);
    const minutes_rem = @trunc(minutes - hours * 60);

    return std.fmt.bufPrint(
        buf, pfx++"{d} h {d} m {d} s", .{hours, minutes_rem, seconds_rem}
    );
}
