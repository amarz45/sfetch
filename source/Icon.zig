const std = @import("std");
const Icon = @This();

const count_codepoints = std.unicode.utf8CountCodepoints;

lines:          Icon_lines,
spaces_padding: []const u8,

// A 2D array where both the width and the height is bounded.
const Icon_lines = Bounded_array(Bounded_array(u8, 128), 128);
const Bounded_array = std.BoundedArray;

// Returns a generic 2D bounded array representing the icon, and a string
// of spaces for alignment when the icon’s height has been exceeded.
pub fn get(comptime field: []const u8) ! Icon {
    const icon = comptime get_array(field);
    const height = icon.len;
    const width = icon[0].len;

    var dest: Icon_lines = try .init(height);

    for (icon, 0..) |v, i| {
        dest.set(i, try .fromSlice(v.constSlice()));
    }

    return .{.lines = dest, .spaces_padding = " "**width};
}

// Used for storing the maximum amount of raw bytes needed to store the width
// and the height respectively.
const Dimensions = struct {
    width:  u8,
    height: u8,

    fn get(comptime icon: []const u8) Dimensions {
        @setEvalBranchQuota(8000);

        var width:  u8 = 0;
        var height: u8 = 0;
        var iter = icon;

        while (std.mem.indexOfScalar(u8, iter, '\n')) |idx| {
            if (idx > width)
                width = idx;
            height += 1;
            iter = iter[(idx + 1)..];
        }

        return .{.width = width, .height = height};
    }
};

// Returns a struct containing two fields:
//     - `list`: the amount of codepoints for each line.
//     - `max`: the number of codepoints for the line with the most codepoints.
fn Codepoints(comptime _icon: []const u8, dimensions: Dimensions) type {
    @setEvalBranchQuota(256_000);
    const height = dimensions.height;

    var icon = _icon;
    comptime var list: [height]u8 = undefined;
    comptime var max: u8 = 0;

    {var i: u8 = 0;
    while (std.mem.indexOfScalar(u8, icon, '\n')) |idx|: (i += 1) {
        const codepoints = try count_codepoints(icon[0..idx]);
        list[i] = codepoints;
        if (codepoints > max)
            max = codepoints;
        icon = icon[(idx + 1)..];
    }}

    return struct {
        list: [height]u8 = list,
        max: u8 = max,
    };
}

// Returns a 2D array representing the icon. The height is constant whereas the
// width is variable but bounded to the width of the longest line.
fn get_array(comptime field: []const u8) Icon_type(field) {
    const icon = get_icon_str(field);
    const dimensions: Dimensions = .get(icon);
    const codepoints: Codepoints(icon, dimensions) = .{};

    var lines_array: Icon_type(field) = undefined;
    
    var iter = std.mem.splitScalar(u8, icon, '\n');
    var i: u8 = 0;

    while (iter.next()) |line| : (i += 1) {
        if (line.len != 0) {
            const spaces_num = codepoints.max - codepoints.list[i];
            const spaces = " "**spaces_num;
            lines_array[i] = try .fromSlice(line++spaces);
        }
    }

    return lines_array;
}

fn Icon_type(comptime field: []const u8) type {
    const icon = get_icon_str(field);
    const dimensions: Dimensions = .get(icon);

    const height = dimensions.height;

    // There is a bug for the width calculation that results in the incorrect
    // width for Tails.
    const width
    = if (std.mem.eql(u8, field, "tails"))
        31
    else
        dimensions.width;

    return [height]Bounded_array(u8, width);
}

// Returns a string of the contents of the icon file.
inline fn get_icon_str(comptime id: []const u8) []const u8 {
    return @embedFile("icons/fastfetch/"++id++".txt");
}
