const std = @import("std");

const token_module = @import("token.zig");
const Token = token_module.Token;
const TokenVariants = token_module.TokenVariants;

const LexerErrors = error{
    TooManyDotsInNumber,
    UnknwonSymbolInSequence,
};

const Lexer = struct {
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
    fn skip_whitespace(self: *Lexer) void {
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
        defer identifier_str.deinit();

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
                if (dot_found) return LexerErrors.TooManyDotsInNumber;
                dot_found = true;
            }
            try number_str.append(self.current_char.?);
            self.advance();
        }
        if (self.current_char != null) self.pos -= 1;
        return std.fmt.parseFloat(f64, number_str.items);
    }
    pub fn next_token(self: *Lexer) !Token {
        self.skip_whitespace();
        self.advance();
        if (self.current_char == null) return Token{ .variant = TokenVariants.eof };
        return switch (self.current_char.?) {
            '+' => Token.create_simple_token(TokenVariants.add),
            '-' => Token.create_simple_token(TokenVariants.sub),
            '*' => Token.create_simple_token(TokenVariants.mul),
            '/' => Token.create_simple_token(TokenVariants.div),
            '(' => Token.create_simple_token(TokenVariants.lpar),
            ')' => Token.create_simple_token(TokenVariants.rpar),
            'a'...'z', 'A'...'Z', '_' => try Token.create_identifier(try self.identifier()),
            '0'...'9', '.' => try Token.create_number(self.alloc, try self.number()),
            else => LexerErrors.UnknwonSymbolInSequence,
        };
    }
};

test "complete lexer test" {
    // var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    // const alloc = arena.allocator();
    const alloc = std.testing.allocator;

    const input: []const u8 = "   identifier +   1234 (   text84_yes/94.40 ) + .88   ";
    var lexer = Lexer{ .input = input, .alloc = alloc };

    const identifier_str = "identifier";
    const identifier_ptr = try alloc.alloc(u8, identifier_str.len);
    std.mem.copyBackwards(u8, identifier_ptr, identifier_str);

    const text84_yes_str = "text84_yes";
    const text84_yes_ptr = try alloc.alloc(u8, text84_yes_str.len);
    std.mem.copyBackwards(u8, text84_yes_ptr, text84_yes_str);

    const expected_tokens = [_]Token{
        try Token.create_identifier(identifier_ptr),
        Token{ .variant = TokenVariants.add },
        try Token.create_number(alloc, 1234),
        Token{ .variant = TokenVariants.lpar },
        try Token.create_identifier(text84_yes_ptr),
        Token{ .variant = TokenVariants.div },
        try Token.create_number(alloc, 94.40),
        Token{ .variant = TokenVariants.rpar },
        Token{ .variant = TokenVariants.add },
        try Token.create_number(alloc, 0.88),
        Token{ .variant = TokenVariants.eof },
    };

    for (&expected_tokens) |*expected| {
        const token = try lexer.next_token();
        try std.testing.expect(token.eql(expected));

        token.destroy(alloc);
        expected.destroy(alloc);
    }
}
