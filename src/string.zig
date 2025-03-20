const std = @import("std");
const Allocator = std.mem.Allocator;

pub const String = struct {
    bytes: []u8,
    pub fn create(alloc: Allocator, bytes: []u8) !String {
        const heap_ptr = try alloc.alloc(u8, bytes.len);
        std.mem.copyBackwards(u8, heap_ptr, bytes);
        return String{ .bytes = heap_ptr };
    }
    pub fn free(alloc: Allocator, self: *String) void {
        alloc.free(self.bytes);
    }
    pub fn clone(alloc: Allocator, self: *String) !String {
        const heap_ptr = try alloc.alloc(u8, self.bytes.len);
        std.mem.copyBackwards(u8, heap_ptr, self.bytes);
        return String{ .bytes = heap_ptr };
    }
};
