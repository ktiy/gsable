ptr: sbl.Array,
pos: usize,

pub fn init(ptr: sbl.Array) ArrayIterator {
    return .{
        .ptr = ptr,
        .pos = 0,
    };
}

pub fn next(self: *ArrayIterator) ?sbl.Cell {
    if (self.pos >= self.ptr.header.len) return null;
    defer self.pos += 1;

    if (self.ptr.is_any()) {
        const x = self.ptr.any_slice()[self.pos];
        return x;
    }

    unreachable;
}

const ArrayIterator = @This();
const sbl = @import("sbl");
