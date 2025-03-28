const std = @import("std");

const t = @import("token.zig");

pub const Error = error{
    TooManyDotsInNumber,
    UnknwonSymbolInSequence,
};

pub const Lexer = struct {
    input: []const u8,
    pos: usize = 0,
    current_char: ?u8 = null,
    alloc: std.mem.Allocator = undefined,

    fn advance(self: *Lexer) void {
        if (self.pos >= self.input.len) {
            self.current_char = null;
            return;
        }
        self.current_char = self.input[self.pos];
        self.pos += 1;
    }
    fn peek(self: *Lexer, pos: usize) ?u8 {
        if (pos >= self.input.len) return null;
        return self.input[pos];
    }
    fn skipWitespace(self: *Lexer) void {
        while (self.pos < self.input.len) {
            const char = self.input[self.pos];
            if (!std.ascii.isWhitespace(char)) break;
            self.pos += 1;
        }
        if (self.pos >= self.input.len) {
            self.current_char = null;
            return;
        }
        self.current_char = self.input[self.pos];
    }
    fn identifier(self: *Lexer) ![]u8 {
        var identifier_str = std.ArrayList(u8).init(self.alloc);
        errdefer identifier_str.deinit();

        while (self.current_char != null and (std.ascii.isAlphanumeric(self.current_char.?) or self.current_char.? == '_')) {
            try identifier_str.append(self.current_char.?);
            self.advance();
        }
        if (self.current_char != null) self.pos -= 1;

        return identifier_str.toOwnedSlice();
    }
    fn number(self: *Lexer) !f64 {
        var number_str = std.ArrayList(u8).init(self.alloc);
        defer number_str.deinit();

        var dot_found = false;

        while (self.current_char != null and (std.ascii.isDigit(self.current_char.?) or self.current_char.? == '.')) {
            if (self.current_char.? == '.') {
                if (dot_found) return Error.TooManyDotsInNumber;
                dot_found = true;
            }
            try number_str.append(self.current_char.?);
            self.advance();
        }
        if (self.current_char != null) self.pos -= 1;
        return std.fmt.parseFloat(f64, number_str.items);
    }
    pub fn nextToken(self: *Lexer) !t.Token {
        self.skipWitespace();
        self.advance();
        if (self.current_char == null) return try t.Token.createBasic(t.Variants.eof);
        return switch (self.current_char.?) {
            '{' => try t.Token.createBasic(t.Variants.begin),
            '}' => try t.Token.createBasic(t.Variants.end),
            '=' => try t.Token.createBasic(t.Variants.assign),
            ';' => try t.Token.createBasic(t.Variants.semicolon),
            '+' => try t.Token.createBasic(t.Variants.add),
            '-' => try t.Token.createBasic(t.Variants.sub),
            '*' => try t.Token.createBasic(t.Variants.mul),
            '/' => try t.Token.createBasic(t.Variants.div),
            '(' => try t.Token.createBasic(t.Variants.lpar),
            ')' => try t.Token.createBasic(t.Variants.rpar),
            'a'...'z', 'A'...'Z', '_' => try t.Token.createIdentifier(self.alloc, try self.identifier(), false),
            '0'...'9', '.' => try t.Token.createNumber(self.alloc, try self.number()),
            else => Error.UnknwonSymbolInSequence,
        };
    }
};

test "v1 lexer" {
    // var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    // const alloc = arena.allocator();
    const alloc = std.testing.allocator;

    const input: []const u8 = "   identifier +   1234 (   text84_yes/94.40 ) + .88   ";
    var lexer = Lexer{ .input = input, .alloc = alloc };

    const expected_tokens = [_]t.Token{
        try t.Token.createIdentifier(alloc, "identifier", true),
        try t.Token.createBasic(t.Variants.add),
        try t.Token.createNumber(alloc, 1234),
        try t.Token.createBasic(t.Variants.lpar),
        try t.Token.createIdentifier(alloc, "text84_yes", true),
        try t.Token.createBasic(t.Variants.div),
        try t.Token.createNumber(alloc, 94.40),
        try t.Token.createBasic(t.Variants.rpar),
        try t.Token.createBasic(t.Variants.add),
        try t.Token.createNumber(alloc, 0.88),
    };

    for (&expected_tokens) |*expected| {
        const token = try lexer.nextToken();
        try std.testing.expect(token.eql(expected));

        token.destroy(alloc);
        expected.destroy(alloc);
    }
}

test "v2 lexer" {
    const alloc = std.testing.allocator;

    const input = "{ x = 23 + 4; y = x / 2; }";
    var lexer = Lexer{ .input = input, .alloc = alloc };

    const expected_tokens = [_]t.Token{
        try t.Token.createBasic(t.Variants.begin),
        try t.Token.createIdentifier(alloc, "x", true),
        try t.Token.createBasic(t.Variants.assign),
        try t.Token.createNumber(alloc, 23),
        try t.Token.createBasic(t.Variants.add),
        try t.Token.createNumber(alloc, 4),
        try t.Token.createBasic(t.Variants.semicolon),
        try t.Token.createIdentifier(alloc, "y", true),
        try t.Token.createBasic(t.Variants.assign),
        try t.Token.createIdentifier(alloc, "x", true),
        try t.Token.createBasic(t.Variants.div),
        try t.Token.createNumber(alloc, 2),
        try t.Token.createBasic(t.Variants.semicolon),
        try t.Token.createBasic(t.Variants.end),
    };

    for (&expected_tokens) |*expected| {
        const token = try lexer.nextToken();
        try std.testing.expect(token.eql(expected));

        expected.destroy(alloc);
        token.destroy(alloc);
    }
}
