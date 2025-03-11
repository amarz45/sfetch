const std = @import("std");
const global = @import("global.zig");
const modules = @import("modules.zig");
const util = @import("util.zig");

const c = @cImport({
    @cInclude("sqlite3.h");
});

const cwd = std.fs.cwd();

const color_set = modules.color_set;
const color_reset = modules.color_reset;

pub fn get_user(buf: []u8, os: modules.Os) ! []const u8 {
    const pfx = color_set++"Packages (user):"++color_reset++" ";

    const num, const pkg_format = switch (os) {
        .alpine => a: {
            const num = try count_newlines("/etc/apk/world");
            break :a .{num, "apk"};
        },
        .gentoo => a: {
            const num = try count_newlines("/var/lib/portage/world");
            break :a .{num, "portage"};
        },
        else => return pfx++"Not implemented for your package format.",
    };

    return std.fmt.bufPrint(buf, pfx++"{} ({s})", .{num, pkg_format});
}

fn create_dir_and_open(base_dir: std.fs.Dir, dir_name: []const u8)
! std.fs.Dir {
    base_dir.access(dir_name, .{})
    catch |err| switch (err) {
        error.FileNotFound => try base_dir.makeDir(dir_name),
        else => return err,
    };

    return base_dir.openDir(dir_name, .{});
}

pub fn get_total(buf: []u8, os: modules.Os) ! []const u8 {
    const xdg_cache_home = std.posix.getenv("XDG_CACHE_HOME");
    var buf_: [64]u8 = undefined;

    const cache_dir_name = xdg_cache_home orelse a: {
        const home = std.posix.getenv("HOME") orelse
            try util.perror("home directory not found.", 1);
        break :a try std.fmt.bufPrint(&buf_, "{s}/.cache", .{home});
    };

    const cache_base_dir = try create_dir_and_open(cwd, cache_dir_name);
    const cache_dir = try create_dir_and_open(cache_base_dir, "fetch");

    const pfx = color_set++"Packages (total):"++color_reset++" ";

    const num, const pkg_format = a: switch (os) {
        .alpine => {
            const path = "/lib/apk/db/installed";
            const num = try count_keys(&buf_, cache_dir, path, "C:Q");
            break :a .{num, "apk"};
        },
        .debian, .ubuntu, => {
            const path = "/var/lib/dpkg/status";
            const key = "Status: install ok installed";
            const num = try count_keys(&buf_, cache_dir, path, key);
            break :a .{num, "dpkg"};
        },
        .fedora => {
            const path = "/var/lib/rpm/rpmdb.sqlite";
            const query = "select count(*) from packages";
            const num = try sql_query(&buf_, cache_dir, path, query);
            break :a .{num, "rpm"};
        },
        .gentoo => {
            const path = "/var/db/pkg";
            const num = try count_dirs_in_dir(&buf_, cache_dir, path);
            break :a .{num, "portage"};
        },
        //.loc_os => {
            //const path = "/opt/Loc-OS-LPKG/installed-lpkg/"
                //++ "Listinstalled-lpkg.list";
            //const num = try count_newlines_str(&buf_, path);
            //break :a .{num, "lpkg"};
        //},
        else => return pfx++"Not implemented for your package format.",
    };

    return std.fmt.bufPrint(buf, pfx++"{s} ({s})", .{num, pkg_format});
}

fn count_newlines_str(buf: []u8, path: []const u8) ! []const u8 {
    const count = try count_newlines(path);
    return std.fmt.bufPrint(buf, "{}", .{count});
}

fn count_newlines(path: []const u8) ! u16 {
    const file = try cwd.openFile(path, .{});

    var file_buf: [std.heap.page_size_min]u8 = undefined;
    const bytes_read = try file.preadAll(&file_buf, 0);
    const str = file_buf[0..bytes_read];

    var count: u16 = 0;

    {var start: usize = 0;
    while (std.mem.indexOfScalarPos(u8, str, start, '\n')) |idx|
    : (start = idx + 1)
        count +|= 1;
    }

    return count;
}

fn count_dirs_in_dir(
    buf: []u8,
    cache_dir: std.fs.Dir,
    dir_path: []const u8,
)
! []const u8 {
    const dir = try cwd.openDir(dir_path, .{.iterate = true});
    const modified = (try dir.metadata()).modified();
    const cached = try check_cache(buf, cache_dir, modified);

    return cached orelse a: {
        const cache_file = try cache_dir.createFile("p", .{});
        const packages = try count_dirs_in_dir_uncached(dir);
        break :a update_cache_and_return(buf, cache_file, modified, packages);
    };
}

fn count_dirs_in_dir_uncached(outer_dir: std.fs.Dir) ! u16 {
    var count: u16 = 0;

    {var iter = outer_dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind == .directory) {
            const dir = try outer_dir.openDir(
                entry.name, .{.iterate = true}
            );
            count +|= try count_dirs(dir);
        }
    }}

    return count;
}

fn count_dirs(dir: std.fs.Dir) ! u16 {
    var count: u16 = 0;

    {var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind == .directory)
            count +|= 1;
    }}

    return count;
}

fn count_keys(
    buf: []u8,
    cache_dir: std.fs.Dir,
    filepath: []const u8,
    key: []const u8,
)
! []const u8 {
    const file = try cwd.openFile(filepath, .{});
    const modified = (try file.metadata()).modified();
    const cached = try check_cache(buf, cache_dir, modified);

    return cached orelse a: {
        const cache_file = try cache_dir.createFile("p", .{});
        const packages = try count_keys_uncached(file, key);
        break :a update_cache_and_return(buf, cache_file, modified, packages);
    };
}

fn count_keys_uncached(file: std.fs.File, key: []const u8) ! u16 {
    var count: u16 = 0;

    var file_buf: [4 * std.heap.page_size_min]u8 = undefined;
    var offset: u64 = 0;

    while (true) {
        const bytes_read = try file.preadAll(&file_buf, offset);

        const str = file_buf[0..bytes_read];

        if (str.len < key.len)
            break;

        if (std.mem.eql(u8, str[0..key.len], key))
            count +|= 1;

        {var start: usize = 0;
        while (std.mem.indexOfScalarPos(u8, str, start, '\n')) |_idx| {
            const idx = _idx + 1;
            if (str.len < idx + key.len)
                break;
            if (std.mem.eql(u8, str[idx..][0..key.len], key))
                count +|= 1;
            start = idx;
        }}

        if (bytes_read != file_buf.len)
            break;

        offset += bytes_read - key.len + 1;
    }

    return count;
}

fn sql_query(
    buf: []u8,
    cache_dir: std.fs.Dir,
    comptime filepath: [:0]const u8,
    comptime query: [:0]const u8,
)
! []const u8 {
    const file = try cwd.openFile(filepath, .{});
    const modified = (try file.metadata()).modified();
    const cached = try check_cache(buf, cache_dir, modified);

    return cached orelse a: {
        const cache_file = try cache_dir.createFile("p", .{});
        const packages = try sql_query_uncached(filepath, query);
        break :a update_cache_and_return(buf, cache_file, modified, packages);
    };
}

fn sql_query_uncached(
    comptime filepath: [:0]const u8,
    comptime query: [:0]const u8,
)
! c_int {
    var db: *allowzero c.sqlite3 = undefined;
    defer _ = c.sqlite3_close(db);

    var stmt: *allowzero c.sqlite3_stmt = undefined;
    defer _ = c.sqlite3_finalize(stmt);

    var rc: c_int = c.sqlite3_open(filepath, &db);
    if (rc != 0)
        try util.perrorf("Error: {s}: failed to open file.\n", .{filepath}, 1);

    rc = c.sqlite3_prepare_v2(db, query, -1, &stmt, 0);
    if (rc != c.SQLITE_OK) {
        try global.stderr.writeAll("Error: failed to execute query.\n");
        _ = c.sqlite3_close(db);
        std.process.exit(1);
    }

    rc = c.sqlite3_step(stmt);
    if (rc != c.SQLITE_ROW) {
        try global.stderr.writeAll("Error: failed to retrieve data.\n");
        _ = c.sqlite3_close(db);
        std.process.exit(1);
    }

    return c.sqlite3_column_int(stmt, 0);
}

fn check_cache(
    buf: []u8,
    cache_dir: std.fs.Dir,
    modified: i128,
)
! ?[]const u8 {
    const file = cache_dir.openFile("p", .{.mode = .read_write})
    catch |err| switch (err) {
        error.FileNotFound => return null,
        else => return err,
    };

    const bytes_read = try file.preadAll(buf, 0);
    if (bytes_read == 0)
        return null;

    const contents = buf[0..bytes_read];

    const newline_i = std.mem.indexOfScalar(u8, contents, '\n') orelse
        return null;

    const timestamp_str = buf[0..newline_i];
    const timestamp = try std.fmt.parseInt(i128, timestamp_str, 10);

    if (timestamp != modified)
        return null;

    return buf[(newline_i + 1)..];
}

fn update_cache_and_return(
    buf: []u8,
    pkg_file: std.fs.File,
    modified: i128,
    packages: anytype,
)
! []const u8 {
    const writer = pkg_file.writer();
    try writer.print("{}\n{}", .{modified, packages});
    return std.fmt.bufPrint(buf, "{}", .{packages});
}
