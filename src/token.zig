const std = @import("std");
const Allocator = std.mem.Allocator;
const Rc = @import("ref_counter.zig").Rc;

pub const Variants = enum {
    //void/symbolic variants
    add,
    sub,
    mul,
    div,
    lpar,
    rpar,
    eof,

    //variants with data
    number,
    string,
    identifier,
};

pub const Error = error{
    BadGetNumber,
    BadGetIdentifier,
    NonVoidVariant,
};

pub const Token = union(Variants) {
    add: void,
    sub: void,
    mul: void,
    div: void,
    lpar: void,
    rpar: void,
    eof: void,

    number: Rc(f64),
    string: Rc([]u8),
    identifier: Rc([]u8),

    pub fn format(self: Token, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        switch (self) {
            .identifier => try writer.print("Id({s})", .{try self.getIdentifier()}),
            .number => try writer.print("Num({d})", .{try self.getNumber()}),
            .add, .sub, .mul, .div => try writer.print("Op({s})", .{@tagName(self.variant())}),
            else => try writer.print("Simb({s})", .{@tagName(self.variant())}),
        }
    }

    pub fn getNumber(self: *const Token) !f64 {
        switch (self.*) {
            .number => return self.number.data.*,
            else => return Error.BadGetNumber,
        }
    }

    pub fn getIdentifier(self: *const Token) ![]u8 {
        switch (self.*) {
            .identifier => return self.identifier.data,
            else => return Error.BadGetIdentifier,
        }
    }

    pub fn createBasic(v: Variants) !Token {
        return switch (v) {
            .add => .{ .add = {} },
            .sub => .{ .sub = {} },
            .mul => .{ .mul = {} },
            .div => .{ .div = {} },
            .lpar => .{ .lpar = {} },
            .rpar => .{ .rpar = {} },
            .eof => .{ .eof = {} },
            else => Error.NonVoidVariant,
        };
    }

    pub fn createNumber(alloc: Allocator, value: f64) !Token {
        return .{ .number = try Rc(f64).init(alloc, value) };
    }

    /// Create an identifier, if copy is false the return Token will take ownership of the slice, if true it will copy it.
    pub fn createIdentifier(alloc: Allocator, value: []const u8, copy: bool) !Token {
        if (copy) return .{ .identifier = try Rc([]u8).init(alloc, @constCast(value)) };
        return .{ .identifier = try Rc([]u8).manage(alloc, @constCast(value)) };
    }

    pub fn clone(self: *const Token) Token {
        return switch (self.*) {
            .number => |value| .{ .number = value.clone() },
            .string => |value| .{ .string = value.clone() },
            .identifier => |value| .{ .identifier = value.clone() },
            else => self.*,
        };
    }

    pub fn destroy(self: *const @This(), alloc: Allocator) void {
        switch (self.*) {
            .number => |item| item.release(alloc),
            .string => |item| item.release(alloc),
            .identifier => |item| item.release(alloc),
            else => {},
        }
    }

    pub fn eql(self: *const Token, rhs: *const Token) bool {
        if (std.meta.activeTag(self.*) != std.meta.activeTag(rhs.*)) return false;
        switch (self.*) {
            .number => {
                const lhs_value: f64 = self.number.data.*;
                const rhs_value: f64 = rhs.number.data.*;
                return lhs_value == rhs_value;
            },
            .identifier => {
                const lhs_value: []u8 = self.identifier.data;
                const rhs_value: []u8 = rhs.identifier.data;
                return std.mem.eql(u8, lhs_value, rhs_value);
            },
            else => return true,
        }
    }

    pub fn variant(self: *const Token) Variants {
        return std.meta.activeTag(self.*);
    }
};

test "number tokens" {
    const alloc = std.testing.allocator;

    const token42 = try Token.createNumber(alloc, 42.0);
    defer token42.destroy(alloc);

    const token42val = try token42.getNumber();
    try std.testing.expectEqual(token42val, 42.0);

    const other = try Token.createNumber(alloc, 42.0);
    defer other.destroy(alloc);

    try std.testing.expect(token42.eql(&other));
}

test "identifier tokens" {
    const alloc = std.testing.allocator;

    const hello_world = "hello world!";

    const hello_ptr1 = try alloc.alloc(u8, hello_world.len);
    std.mem.copyBackwards(u8, hello_ptr1, hello_world);
    const rhs_token = try Token.createIdentifier(alloc, hello_ptr1, false);
    defer rhs_token.destroy(alloc);

    const hello_ptr2 = try alloc.alloc(u8, hello_world.len);
    std.mem.copyBackwards(u8, hello_ptr2, hello_world);
    const lhs_token = try Token.createIdentifier(alloc, hello_ptr2, false);
    defer lhs_token.destroy(alloc);

    try std.testing.expect(rhs_token.eql(&lhs_token));

    const other_ptr = try alloc.alloc(u8, 3);
    std.mem.copyBackwards(u8, other_ptr, "xyz");
    const other_token = try Token.createIdentifier(alloc, other_ptr, false);
    defer other_token.destroy(alloc);

    try std.testing.expect(!rhs_token.eql(&other_token));
}

test "token equality" {
    const alloc = std.testing.allocator;

    const mul = try Token.createBasic(Variants.mul);
    const other_mul = try Token.createBasic(Variants.mul);
    const not_mul = try Token.createBasic(Variants.add);

    try std.testing.expect(mul.eql(&other_mul));
    try std.testing.expect(!mul.eql(&not_mul));

    const a = try Token.createNumber(alloc, 69);
    defer a.destroy(alloc);

    const b = try Token.createNumber(alloc, 420);
    defer b.destroy(alloc);

    try std.testing.expect(!a.eql(&b));
}
