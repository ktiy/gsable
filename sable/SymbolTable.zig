/// Strings are externally owned
const SymTable = @This();

const std = @import("std");

gpa: std.mem.Allocator,
pool: std.array_hash_map.String(void),

pub const Symbol = enum(u32) {
    none = std.math.maxInt(u32),
    _,
};

pub fn init(gpa: std.mem.Allocator) !SymTable {
    return .{
        .gpa = gpa,
        .pool = try .init(gpa, &.{}, &.{}),
    };
}

pub fn deinit(self: *SymTable) void {
    self.pool.deinit(self.gpa);
}

/// id remains externally owned
pub fn intern(self: *SymTable, id: []const u8) !Symbol {
    if (id.len == 0) return .none;
    const elem = try self.pool.getOrPut(self.gpa, id);
    return @enumFromInt(elem.index);
}

pub fn get(self: *SymTable, sym: Symbol) []const u8 {
    if (sym == .none) return "";
    return self.pool.keys()[@intFromEnum(sym)];
}

test "symbol table" {
    const gpa = std.testing.allocator;

    var st: SymTable = try .init(gpa);
    defer st.deinit();

    const hello = try st.intern("hello");
    const hello_str = st.get(hello);

    const hello2 = try st.intern("hello");
    const hello2_str = st.get(hello2);

    try std.testing.expectEqual(hello, hello2);
    try std.testing.expectEqualSlices(u8, hello_str, hello2_str);
    try std.testing.expectEqualSlices(u8, "hello", hello_str);
}
