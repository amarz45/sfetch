const std = @import("std");

const count_codepoints = std.unicode.utf8CountCodepoints;

// A 2D array where both the width and the height is bounded.
const Icon = Bounded_array(Bounded_array(u8, 128), 128);
const Bounded_array = std.BoundedArray;

// Used for storing the maximum amount of raw bytes needed to store the width
// and the height respectively.
const Dimensions = struct {
    width:  u8,
    height: u8,

    fn get(comptime icon: []const u8) Dimensions {
        @setEvalBranchQuota(2000);

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
    @setEvalBranchQuota(16_000);
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

// Returns a generic 2D bounded array representing the icon, and a string
// of spaces for alignment when the icon’s height has been exceeded.
pub inline fn get(comptime field: []const u8) ! struct {Icon, []const u8} {
    const icon = comptime get_array(field);
    const height = icon.len;
    const width = icon[0].len;

    var dest: Icon = try .init(height);

    for (icon, 0..) |v, i| {
        dest.set(i, try .fromSlice(v.constSlice()));
    }

    return .{dest, " "**width};
}

// Returns a 2D array representing the icon. The height is constant whereas the
// width is variable but bounded to the width of the longest line.
fn get_array(comptime field: []const u8) Icon_type(field) {
    const icon = get_icon_str(field);
    const dimensions: Dimensions = .get(icon);
    const codepoints: Codepoints(icon, dimensions) = .{};

    const height = dimensions.height;
    const width = dimensions.width;

    var lines_array: [height]Bounded_array(u8, width) = undefined;
    
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
    const width  = dimensions.width;

    return [height]Bounded_array(u8, width);
}

// Returns a string of the contents of the icon file.
inline fn get_icon_str(comptime field: []const u8) []const u8 {
    return if (std.mem.eql(u8, field, "locos"))
        get_icon_file_large(field)
    else
        get_icon_file(field);
}

inline fn get_icon_file(comptime icon: []const u8) []const u8 {
    return @embedFile("icons/fastfetch/"++icon++"_small.txt");
}

inline fn get_icon_file_large(comptime icon: []const u8) []const u8 {
    return @embedFile("icons/fastfetch/"++icon++".txt");
}
