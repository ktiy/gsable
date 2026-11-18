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

    return self.ptr.get(self.pos);
}

const ArrayIterator = @This();
const sbl = @import("sbl");
