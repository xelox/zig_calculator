const std = @import("std");
const Allocator = std.mem.Allocator;
const Arena = std.heap.ArenaAllocator;
const Rc = @import("ref_counter.zig").Rc;

pub const Variants = enum {
    //statements
    begin,
    end,
    semicolon,

    //expr symbols
    add,
    sub,
    mul,
    div,
    lpar,
    rpar,
    eof,

    //variables
    integer,
    float,
    string,
    identifier,
    assign,
};

pub const Error = error{
    BadGetNumber,
    BadGetIdentifier,
    NonVoidVariant,
};

pub const Token = union(Variants) {
    begin: void,
    end: void,
    semicolon: void,

    add: void,
    sub: void,
    mul: void,
    div: void,
    lpar: void,
    rpar: void,
    eof: void,

    integer: i64,
    float: f64,
    string: []u8,
    identifier: []const u8,
    assign: void,

    pub fn format(self: Token, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        switch (self) {
            .identifier => |value| try writer.print("Id({s})", .{value}),
            .float => |value| try writer.print("Float({d})", .{value}),
            .integer => |value| try writer.print("Int({d})", .{value}),
            .add, .sub, .mul, .div => try writer.print("Op({s})", .{@tagName(self.variant())}),
            else => try writer.print("Simb({s})", .{@tagName(self.variant())}),
        }
    }

    pub fn createBasic(v: Variants) !Token {
        return switch (v) {
            .begin => .{ .begin = {} },
            .end => .{ .end = {} },
            .semicolon => .{ .semicolon = {} },
            .assign => .{ .assign = {} },
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

    pub fn createFloat(src: f64) Token {
        return .{ .float = src };
    }

    pub fn createInteger(src: i64) Token {
        return .{ .integer = src };
    }

    /// Create an identifier, if copy is false the return Token will take ownership of the slice, if true it will copy it.
    pub fn createIdentifier(alloc: Allocator, src: []const u8, do_copy: bool) !Token {
        const slice = if (!do_copy) src else blk: {
            const new_slice = try alloc.alloc(u8, src.len);
            @memcpy(new_slice, src);
            break :blk new_slice;
        };
        return .{ .identifier = slice };
    }

    // Performs deep copy for heap allocated slices.
    pub fn copy(self: *const Token, alloc: Allocator) Token {
        return switch (self.*) {
            .string => |value| blk: {
                const new_slice = alloc.alloc(u8, value.len);
                @memcpy(new_slice, value);
                break :blk .{ .string = new_slice };
            },
            .identifier => |value| blk: {
                const new_slice = alloc.alloc(u8, value.len);
                @memcpy(new_slice, value);
                break :blk .{ .identifier = new_slice };
            },
            else => self.*,
        };
    }

    pub fn free(self: *const Token, alloc: Allocator) void {
        switch (self.*) {
            .string => |mem| alloc.free(mem),
            .identifier => |mem| alloc.free(mem),
            else => {},
        }
    }

    pub fn eql(self: *const Token, other: *const Token) bool {
        if (self.variant() != other.variant()) return false;
        return switch (self.*) {
            .float => self.float == other.float,
            .integer => self.integer == other.integer,
            .identifier => std.mem.eql(u8, self.identifier, other.identifier),
            .string => std.mem.eql(u8, self.string, other.string),
            else => true,
        };
    }

    pub fn variant(self: *const Token) Variants {
        return std.meta.activeTag(self.*);
    }
};

test "number tokens" {
    const token42 = Token.createFloat(42.0);

    const token42val = token42.float;
    try std.testing.expectEqual(token42val, 42.0);

    const other = Token.createFloat(42.0);

    try std.testing.expect(token42.eql(&other));
}

test "identifier tokens" {
    const alloc = std.testing.allocator;

    const hello_world_str = "hello world!";

    const hello_ptr1 = try alloc.alloc(u8, hello_world_str.len);
    @memcpy(hello_ptr1, hello_world_str);

    // identifier token created from heap string
    const rhs_token = try Token.createIdentifier(alloc, hello_ptr1, false);
    defer rhs_token.free(alloc);

    // identifier token created from static string
    const lhs_token = try Token.createIdentifier(alloc, "hello world!", true);
    defer lhs_token.free(alloc);

    try std.testing.expect(rhs_token.eql(&lhs_token));

    const other_token = try Token.createIdentifier(alloc, "xyz", true);
    defer other_token.free(alloc);

    try std.testing.expect(!rhs_token.eql(&other_token));
}

test "token equality" {
    const mul = try Token.createBasic(.mul);
    const other_mul = try Token.createBasic(.mul);
    const not_mul = try Token.createBasic(.add);

    try std.testing.expect(mul.eql(&other_mul));
    try std.testing.expect(!mul.eql(&not_mul));

    const a = Token.createInteger(69);
    const b = Token.createInteger(420);
    const z = Token.createInteger(69);

    try std.testing.expect(!a.eql(&b));
    try std.testing.expect(a.eql(&z));
}
