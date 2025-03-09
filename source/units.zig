pub fn Byte(T: type) type {
    return struct {v: T};
}

pub fn Kib(T: type) type {
    return struct {v: T};
}

pub fn Mib(T: type) type {
    return struct {
        const Self = @This();

        v: T,

        pub inline fn from_bytes(bytes: Byte(T)) Self {
            return .{.v = bytes.v / (1 << 20)};
        }

        pub inline fn from_kib(kib: Kib(T)) Self {
            return .{.v = kib.v / (1 << 10)};
        }
    };
}
