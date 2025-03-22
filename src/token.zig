const std = @import("std");
const Allocator = std.mem.Allocator;
const Rc = @import("ref_counter.zig").Rc;

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

pub const TokenValue = union(enum) {
    string: Rc([]u8),
    number: Rc(f64),
};

pub const Token = struct {
    variant: TokenVariants,
    value: ?TokenValue = null,

    pub fn format(self: Token, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        switch (self.variant) {
            TokenVariants.identifier => {
                const str = try self.getIdentifier();
                try writer.print("Token({s}, {s})", .{ @tagName(self.variant), str });
            },
            TokenVariants.number => {
                const num = try self.getNumber();
                try writer.print("Token({s}, {d})", .{ @tagName(self.variant), num });
            },
            else => {
                try writer.print("Token({s}, null)", .{@tagName(self.variant)});
            },
        }
    }

    pub fn createBasic(variant: TokenVariants) Token {
        return Token{ .variant = variant };
    }

    pub fn createNumber(alloc: Allocator, value: f64) !Token {
        return Token{
            .variant = TokenVariants.number,
            .value = TokenValue{ .number = try Rc(f64).init(alloc, value) },
        };
    }

    /// Create an identifier by taking ownership of heap allocated memory
    pub fn createIdentifier(alloc: Allocator, value: []const u8) !Token {
        return Token{
            .variant = TokenVariants.identifier,
            .value = TokenValue{ .string = try Rc([]u8).manage(alloc, @constCast(value)) },
        };
    }

    pub fn getNumber(self: *const Token) !f64 {
        if (self.value == null) return TokenError.BadGetNumber;
        return self.value.?.number.data.*;
    }

    pub fn getIdentifier(self: *const Token) ![]u8 {
        if (self.value == null) return TokenError.BadGetIdentifier;
        return self.value.?.string.data;
    }

    pub fn destroy(self: *const Token, alloc: Allocator) void {
        if (self.value == null) return;
        switch (self.value.?) {
            .number => |num| num.release(alloc),
            .string => |str| str.release(alloc),
        }
    }

    pub fn eql(self: *const Token, rhs: *const Token) bool {
        if (self.variant != rhs.variant) return false;
        switch (self.variant) {
            TokenVariants.number => {
                const lhs_value: f64 = self.value.?.number.data.*;
                const rhs_value: f64 = rhs.value.?.number.data.*;
                return lhs_value == rhs_value;
            },
            TokenVariants.identifier => {
                const lhs_value: []u8 = self.value.?.string.data;
                const rhs_value: []u8 = rhs.value.?.string.data;
                return std.mem.eql(u8, lhs_value, rhs_value);
            },
            else => return true,
        }
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
    const rhs_token = try Token.createIdentifier(alloc, hello_ptr1);
    defer rhs_token.destroy(alloc);

    const hello_ptr2 = try alloc.alloc(u8, hello_world.len);
    std.mem.copyBackwards(u8, hello_ptr2, hello_world);
    const lhs_token = try Token.createIdentifier(alloc, hello_ptr2);
    defer lhs_token.destroy(alloc);

    try std.testing.expect(rhs_token.eql(&lhs_token));

    const other_ptr = try alloc.alloc(u8, 3);
    std.mem.copyBackwards(u8, other_ptr, "xyz");
    const other_token = try Token.createIdentifier(alloc, other_ptr);
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

    const a = try Token.createNumber(alloc, 69);
    defer a.destroy(alloc);

    const b = try Token.createNumber(alloc, 420);
    defer b.destroy(alloc);

    try std.testing.expect(!a.eql(&b));
}
