const std = @import("std");
const Allocator = std.mem.Allocator;

fn isSlice(T: type) bool {
    return comptime switch (@typeInfo(T)) {
        .pointer => |ptr| ptr.size == .slice,
        else => false,
    };
}

pub fn Rc(comptime T: type) type {
    const is_slice = comptime isSlice(T);

    return struct {
        ref_counter: *usize,
        been_released: bool = false,
        data: if (is_slice) T else *T,

        /// Initializes a new Rc by copying memory from source to a new region in memory.
        pub fn init(alloc: Allocator, source: T) !@This() {
            const ref_counter_ptr = try alloc.create(usize);
            errdefer alloc.destroy(ref_counter_ptr);
            ref_counter_ptr.* = 1;

            if (is_slice) {
                const child_type = std.meta.Child(T);
                const data_slice = try alloc.alloc(child_type, source.len);
                @memcpy(data_slice, source);
                return .{ .ref_counter = ref_counter_ptr, .data = data_slice };
            } else {
                const data_ptr = try alloc.create(T);
                data_ptr.* = source;
                return .{ .ref_counter = ref_counter_ptr, .data = data_ptr };
            }
        }

        /// Initializes a new Rc by taking ownership of the source memory. No copy will be made.
        pub fn manage(alloc: Allocator, source: if (is_slice) T else *T) !@This() {
            const ref_counter_ptr = try alloc.create(usize);
            errdefer alloc.destroy(ref_counter_ptr);
            ref_counter_ptr.* = 1;
            return .{ .ref_counter = ref_counter_ptr, .data = source };
        }

        /// Increase the ref counter and get a new Rc.
        pub fn clone(self: *const @This()) @This() {
            self.ref_counter.* += 1;
            return .{ .ref_counter = self.ref_counter, .data = self.data };
        }

        /// Release an instance of Rc and free if all references have been released.
        /// calling twice on the same instance does nothing in release builds, but it panics in debug builds.
        pub fn release(self: *const @This(), alloc: Allocator) void {
            std.debug.assert(!self.been_released);
            if (self.been_released) return;
            @constCast(self).been_released = true;
            self.ref_counter.* -= 1;
            if (self.ref_counter.* == 0) {
                alloc.destroy(self.ref_counter);
                if (is_slice) {
                    alloc.free(self.data);
                } else {
                    alloc.destroy(self.data);
                }
            }
        }
    };
}

test "Rc f64" {
    const alloc = std.testing.allocator;
    const a = try Rc(f64).init(alloc, 420.69);
    defer a.release(alloc);

    const b = a.clone();
    defer b.release(alloc);

    try std.testing.expectEqual(420.69, a.data.*);
    try std.testing.expectEqual(420.69, b.data.*);
}

test "Rc slice" {
    const alloc = std.testing.allocator;
    const a = try Rc([]u8).init(alloc, @constCast(&[_]u8{ 0, 1, 2, 3 }));
    defer a.release(alloc);

    const b = a.clone();
    defer b.release(alloc);

    try std.testing.expectEqualSlices(u8, &[_]u8{ 0, 1, 2, 3 }, a.data);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0, 1, 2, 3 }, b.data);
}

test "Rc random slice" {
    const alloc = std.testing.allocator;

    const len = std.crypto.random.intRangeAtMost(usize, 5, 20);
    const buffer = try alloc.alloc(u8, len);
    defer alloc.free(buffer);
    std.crypto.random.bytes(buffer);

    const a = try Rc([]u8).init(alloc, buffer);
    defer a.release(alloc);

    const b = a.clone();
    defer b.release(alloc);

    try std.testing.expect(buffer.ptr != a.data.ptr);
    try std.testing.expect(buffer.ptr != b.data.ptr);
    try std.testing.expectEqual(a.data.ptr, b.data.ptr);

    try std.testing.expectEqualSlices(u8, buffer, a.data);
    try std.testing.expectEqualSlices(u8, buffer, b.data);
}

test "Rc manage random slice" {
    const alloc = std.testing.allocator;

    const len = std.crypto.random.intRangeAtMost(usize, 5, 20);
    const buffer = try alloc.alloc(u8, len);
    std.crypto.random.bytes(buffer);

    const a = try Rc([]u8).manage(alloc, buffer);
    defer a.release(alloc);

    const b = a.clone();
    defer b.release(alloc);

    try std.testing.expect(buffer.ptr == a.data.ptr);
    try std.testing.expect(buffer.ptr == b.data.ptr);
    try std.testing.expectEqual(a.data.ptr, b.data.ptr);

    try std.testing.expectEqualSlices(u8, buffer, a.data);
    try std.testing.expectEqualSlices(u8, buffer, b.data);
}

test "Rc maange u64" {
    const alloc = std.testing.allocator;

    const my_ptr = try alloc.create(u64);
    my_ptr.* = 69;

    const a = try Rc(u64).manage(alloc, my_ptr);
    defer a.release(alloc);

    const b = a.clone();
    defer b.release(alloc);

    try std.testing.expectEqual(my_ptr, a.data);
    try std.testing.expectEqual(a.data, b.data);
}

test "isSlice" {
    try std.testing.expectEqual(true, isSlice([]u8));
    try std.testing.expectEqual(false, isSlice(u8));
    try std.testing.expectEqual(false, isSlice(*u8));
}
