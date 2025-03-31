const std = @import("std");
const Allocator = std.mem.Allocator;
const Arena = std.heap.ArenaAllocator;

const t = @import("token.zig");

pub const Error = error{
    TooManyDotsInNumber,
    UnknwonSymbolInSequence,
};

pub const Lexer = struct {
    input: []const u8 = undefined,
    pos: usize = 0,
    current_char: ?u8 = null,
    alloc: Allocator = undefined,

    pub fn init(arena: *Arena) Lexer {
        const alloc = arena.allocator();
        return .{ .alloc = alloc };
    }

    pub fn set_input(self: *Lexer, input: []const u8) void {
        self.input = input;
        self.pos = 0;
        self.current_char = null;
    }

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
            '0'...'9', '.' => t.Token.createFloat(try self.number()),
            else => Error.UnknwonSymbolInSequence,
        };
    }
};

test "v1 lexer" {
    // var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    // const alloc = arena.allocator();
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var lexer = Lexer.init(&arena);
    lexer.set_input("   identifier +   1234 (   text84_yes/94.40 ) + .88   ");

    const expected_tokens = [_]t.Token{
        try t.Token.createIdentifier(alloc, "identifier", true),
        try t.Token.createBasic(t.Variants.add),
        t.Token.createFloat(1234),
        try t.Token.createBasic(t.Variants.lpar),
        try t.Token.createIdentifier(alloc, "text84_yes", true),
        try t.Token.createBasic(t.Variants.div),
        t.Token.createFloat(94.40),
        try t.Token.createBasic(t.Variants.rpar),
        try t.Token.createBasic(t.Variants.add),
        t.Token.createFloat(0.88),
    };

    for (&expected_tokens) |*expected| {
        const token = try lexer.nextToken();
        try std.testing.expect(token.eql(expected));
    }
}

test "v2 lexer" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var lexer = Lexer.init(&arena);
    lexer.set_input("{ x = 23 + 4; y = x / 2; }");

    const expected_tokens = [_]t.Token{
        try t.Token.createBasic(t.Variants.begin),
        try t.Token.createIdentifier(alloc, "x", true),
        try t.Token.createBasic(t.Variants.assign),
        t.Token.createFloat(23),
        try t.Token.createBasic(t.Variants.add),
        t.Token.createFloat(4),
        try t.Token.createBasic(t.Variants.semicolon),
        try t.Token.createIdentifier(alloc, "y", true),
        try t.Token.createBasic(t.Variants.assign),
        try t.Token.createIdentifier(alloc, "x", true),
        try t.Token.createBasic(t.Variants.div),
        t.Token.createFloat(2),
        try t.Token.createBasic(t.Variants.semicolon),
        try t.Token.createBasic(t.Variants.end),
    };

    for (&expected_tokens) |*expected| {
        const token = try lexer.nextToken();
        try std.testing.expect(token.eql(expected));
    }
}
