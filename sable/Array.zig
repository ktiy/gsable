const Array = @This();

const std = @import("std");
const assert = std.debug.assert;

const sbl = @import("sbl");
const Cell = sbl.Cell;

header: *Header,

pub const Dim = i64;

pub const Kind = enum(u8) {
    any,

    pub fn Type(comptime self: Kind) Type {
        return switch (self) {
            .any => Cell,
        };
    }

    pub fn array_size(self: Kind, len: u64) usize {
        return switch (self) {
            .any => len * @sizeOf(Cell),
        };
    }
};

pub const Header = extern struct {
    kind: Kind = .any,
    rank: u8,
    refc: u16,
    len: u64,

    comptime {
        assert(@sizeOf(Header) % 8 == 0);
    }

    // payload():
    // .shape(): [rank]Dim,
    // .data():  [len]T,
    pub fn payload(self: *Header) Payload {
        const base: [*]Header = @ptrCast(self);
        const ptr: [*]u8 = @ptrCast(base + 1);
        return .{
            .rank = self.rank,
            .len = self.len,
            .ptr = ptr,
        };
    }
};

pub const Payload = struct {
    rank: usize,
    len: usize,
    ptr: [*]u8,

    pub fn shape(self: Payload) []Dim {
        return self.shape_ptr()[0..self.rank];
    }

    pub fn data(self: Payload, comptime T: type) []T {
        const base: [*]T = @ptrCast(@alignCast(self.data_ptr()));
        return base[0..self.len];
    }

    pub fn shape_ptr(self: Payload) [*]Dim {
        return @ptrCast(@alignCast(self.ptr));
    }

    pub fn data_ptr(self: Payload) [*]u8 {
        return self.ptr + (self.rank * @sizeOf(Dim));
    }
};

pub fn init(
    gpa: std.mem.Allocator,
    sh: []const Dim,
    kind: Kind,
) !Array {
    assert(sh.len <= std.math.maxInt(u8));

    const rank: u8 = @truncate(sh.len);
    var len: u64 = 1;
    for (sh) |dim| len *= @intCast(dim);

    const total = total_size(kind, rank, len);
    const buf = try gpa.alignedAlloc(u8, .fromByteUnits(@alignOf(Header)), total);

    const h: *Header = @ptrCast(buf.ptr);
    h.kind = kind;
    h.rank = rank;
    h.refc = 1;
    h.len = len;

    for (h.payload().shape(), sh) |*dst, dim| {
        dst.* = dim;
    }

    const ptr: Array = .{ .header = h };
    switch (kind) {
        .any => @memset(ptr.any_slice(), .num(0)),
    }

    return ptr;
}

pub fn deinit(self: Array, gpa: std.mem.Allocator) void {
    const kind = self.header.kind;
    const len = self.header.len;
    const rank = self.header.rank;
    const size = total_size(kind, rank, len);
    const buf: [*]align(8) u8 = @ptrCast(self.header);

    gpa.free(buf[0..size]);
}

pub fn iter(self: Array) sbl.ArrayIterator {
    return .init(self);
}

pub fn retain(self: Array) void {
    _ = @atomicRmw(u16, &self.header.refc, .Add, 1, .seq_cst);
}

pub fn release(self: Array, gpa: std.mem.Allocator) void {
    if (@atomicRmw(u16, &self.header.refc, .Sub, 1, .seq_cst) == 1) {
        if (self.is_any()) {
            for (self.any_slice()) |x| {
                if (!x.atom()) x.into(.array).release(gpa);
            }
        }
        self.deinit(gpa);
    }
}

pub fn flat_index(self: Array, is: []const usize) usize {
    const shape = self.header.payload().shape();
    var offset: usize = 0;
    var stride: usize = 1;
    var i: usize = self.header.rank;
    while (i > 0) {
        i -= 1;
        const dim = shape[i];
        offset += is[i] * stride;
        std.debug.assert(dim >= 0);
        stride *= @intCast(dim);
    }
    return offset;
}

pub fn any_slice(self: Array) []Cell {
    return self.header.payload().data(Cell);
}

pub fn is_any(self: Array) bool {
    return self.header.kind == .any;
}

fn total_size(kind: Kind, rank: u8, len: u64) usize {
    const header_size = @sizeOf(Header);
    const shape_size = @as(usize, rank) * @sizeOf(Dim);
    const array_size = kind.array_size(len);
    return header_size + shape_size + array_size;
}

test "array release" {
    const gpa = std.testing.allocator;
    const a = try Array.init(gpa, &.{ 2, 2 }, .any);
    defer a.release(gpa);

    try std.testing.expectEqual(a.header.rank, 2);
    try std.testing.expectEqual(a.header.refc, 1);
}

test "array refc" {
    const gpa = std.testing.allocator;
    const a = try Array.init(gpa, &.{4}, .any);

    a.retain();
    try std.testing.expectEqual(a.header.refc, 2);

    a.release(gpa);
    try std.testing.expectEqual(a.header.refc, 1);

    a.release(gpa);
}

test "array release nested" {
    const gpa = std.testing.allocator;

    const y = try Array.init(gpa, &.{2}, .any);
    const x = try Array.init(gpa, &.{2}, .any);
    x.any_slice()[1] = .array(y);

    x.release(gpa);
}

test "array flat_index" {
    const gpa = std.testing.allocator;
    const shape = [_]i64{ 2, 2 };

    const a = try Array.init(gpa, &shape, .any);
    defer a.release(gpa);

    try std.testing.expectEqual(@as(usize, 0), a.flat_index(&.{ 0, 0 }));
    try std.testing.expectEqual(@as(usize, 1), a.flat_index(&.{ 0, 1 }));
    try std.testing.expectEqual(@as(usize, 2), a.flat_index(&.{ 1, 0 }));
    try std.testing.expectEqual(@as(usize, 3), a.flat_index(&.{ 1, 1 }));
}
