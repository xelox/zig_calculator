const std = @import("std");
const Allocator = std.mem.Allocator;

pub const TokenVariants = enum {
    add,
    sub,
    mul,
    div,
    lpar,
    rpar,
    number,
    identifier,
    eof,
};

pub const TokenError = error{
    BadGetNumber,
    BadGetIdentifier,
};

pub const Token = struct {
    variant: TokenVariants,
    value: *anyopaque = undefined,
    len: usize = 0,

    pub fn format(self: Token, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        switch (self.variant) {
            TokenVariants.identifier => {
                const str = try self.get_identifier();
                try writer.print("Token({s}, {s})", .{ @tagName(self.variant), str });
            },
            TokenVariants.number => {
                const num = try self.get_number();
                try writer.print("Token({s}, {d})", .{ @tagName(self.variant), num });
            },
            else => {
                try writer.print("Token({s}, null)", .{@tagName(self.variant)});
            },
        }
    }

    pub fn create_simple_token(variant: TokenVariants) Token {
        return Token{ .variant = variant };
    }

    pub fn create_number(alloc: Allocator, value: f64) !Token {
        const heap_ptr = try alloc.create(f64);
        heap_ptr.* = value;

        return Token{
            .variant = TokenVariants.number,
            .value = @ptrCast(heap_ptr),
        };
    }

    /// Create an identifier by taking ownership of heap allocated memory
    pub fn create_identifier(value: []const u8) !Token {
        return Token{
            .variant = TokenVariants.identifier,
            .value = @ptrCast(@constCast(value)),
            .len = value.len,
        };
    }

    pub fn destroy(self: *const Token, alloc: Allocator) void {
        switch (self.variant) {
            TokenVariants.number => {
                const f32_ptr: *f64 = @ptrCast(@alignCast(self.value));
                alloc.destroy(f32_ptr);
            },
            TokenVariants.identifier => {
                const str_ptr: []u8 = @as([*]u8, @ptrCast(self.value))[0..self.len];
                alloc.free(str_ptr);
            },
            else => {},
        }
    }

    pub fn get_number(self: *const Token) !f64 {
        if (self.variant != TokenVariants.number) return TokenError.BadGetNumber;
        const f32_ptr: *f64 = @ptrCast(@alignCast(self.value));
        return f32_ptr.*;
    }

    /// returns memory owned memory, use immediatly or copy for later use.
    pub fn get_identifier(self: *const Token) ![]u8 {
        if (self.variant != TokenVariants.identifier) return TokenError.BadGetIdentifier;
        const str_ptr: []u8 = @as([*]u8, @ptrCast(self.value))[0..self.len];
        return str_ptr;
    }

    pub fn eql(self: *const Token, rhs: *const Token) bool {
        if (self.variant != rhs.variant) return false;
        switch (self.variant) {
            TokenVariants.number => {
                const lhs_value = self.get_number() catch unreachable;
                const rhs_value = rhs.get_number() catch unreachable;
                return lhs_value == rhs_value;
            },
            TokenVariants.identifier => {
                const lhs_value = self.get_identifier() catch unreachable;
                const rhs_value = rhs.get_identifier() catch unreachable;
                return std.mem.eql(u8, lhs_value, rhs_value);
            },
            else => return true,
        }
    }
};

test "number tokens" {
    const alloc = std.testing.allocator;

    const token42 = try Token.create_number(alloc, 42.0);
    defer token42.destroy(alloc);

    const token42val = try token42.get_number();
    try std.testing.expectEqual(token42val, 42.0);

    const other = try Token.create_number(alloc, 42.0);
    defer other.destroy(alloc);

    try std.testing.expect(token42.eql(&other));
}

test "identifier tokens" {
    const alloc = std.testing.allocator;

    const hello_world = "hello world!";

    const hello_ptr1 = try alloc.alloc(u8, hello_world.len);
    std.mem.copyBackwards(u8, hello_ptr1, hello_world);
    const rhs_token = try Token.create_identifier(hello_ptr1);
    defer rhs_token.destroy(alloc);

    const hello_ptr2 = try alloc.alloc(u8, hello_world.len);
    std.mem.copyBackwards(u8, hello_ptr2, hello_world);
    const lhs_token = try Token.create_identifier(hello_ptr2);
    defer lhs_token.destroy(alloc);

    try std.testing.expect(rhs_token.eql(&lhs_token));

    const other_ptr = try alloc.alloc(u8, 3);
    std.mem.copyBackwards(u8, other_ptr, "xyz");
    const other_token = try Token.create_identifier(other_ptr);
    defer other_token.destroy(alloc);

    try std.testing.expect(!rhs_token.eql(&other_token));
}

test "token equality" {
    const alloc = std.testing.allocator;

    const mul = Token{ .variant = TokenVariants.mul };
    const other_mul = Token{ .variant = TokenVariants.mul };
    const not_mul = Token{ .variant = TokenVariants.add };

    try std.testing.expect(mul.eql(&other_mul));
    try std.testing.expect(!mul.eql(&not_mul));

    const a = try Token.create_number(alloc, 69);
    defer a.destroy(alloc);

    const b = try Token.create_number(alloc, 420);
    defer b.destroy(alloc);

    try std.testing.expect(!a.eql(&b));
}
