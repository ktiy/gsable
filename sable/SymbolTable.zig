gpa: std.mem.Allocator,
buf: std.ArrayList(u8) = .empty,
strs: std.ArrayList([]const u8) = .empty,

pub const Symbol = enum(u32) {
    none = std.math.maxInt(u32),
    _,
};

pub fn init(gpa: std.mem.Allocator) !SymTable {
    return .{
        .gpa = gpa,
    };
}

pub fn deinit(self: *SymTable) void {
    self.buf.deinit(self.gpa);
    self.strs.deinit(self.gpa);
}

pub fn intern(self: *SymTable, id: []const u8) !Symbol {
    if (id.len == 0) return .none;

    for (self.strs.items, 0..) |str, i| {
        if (std.mem.eql(u8, id, str)) {
            return @fromBackingInt(@truncate(i));
        }
    }

    const i = @as(u32, @truncate(self.strs.items.len));
    try self.buf.appendSlice(self.gpa, id);

    const slice = self.buf.items[i..][0..id.len];
    try self.strs.append(self.gpa, slice);

    return @fromBackingInt(i);
}

pub fn get(self: *SymTable, sym: Symbol) []const u8 {
    if (sym == .none) return "";
    return self.strs.items[@backingInt(sym)];
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

const SymTable = @This();
const std = @import("std");
