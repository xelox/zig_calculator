const std = @import("std");

const token_module = @import("token.zig");
const Token = token_module.Token;

const LexerErrors = error{TooManyDotsInNumber};

const Lexer = struct {
    input: []u8,
    pos: usize = 0,
    current_token: ?Token = null,
    current_char: ?u8 = null,
    alloc: std.mem.Allocator = undefined,

    fn advance(self: *Lexer) ?u8 {
        if (self.pos >= self.input.len) return null;
        self.current_char = self.input[self.pos];
        self.pos += 1;
        return self.current_char;
    }
    fn peek(self: *Lexer, pos: usize) ?u8 {
        if (pos >= self.input.len) return null;
        return self.input[pos];
    }
    fn skip_whitespace(self: *Lexer) void {
        while (self.pos < self.input.len) {
            const char = self.input[self.pos];
            if (std.ascii.isWhitespace(char)) break;
            self.pos += 1;
        }
        self.current_char = self.input[self.pos];
    }
    fn identifier(self: *Lexer) std.ArrayListAligned(u8) {
        var identifier_str = std.ArrayList(u8).init(self.alloc);
        while (std.ascii.isAlphanumeric(self.current_char) or self.current_char == '_') {
            identifier_str.append(self.current_char);
        }
        return identifier_str;
    }
    fn number(self: *Lexer) !f64 {
        var number_str = std.ArrayList(u8).init(self.alloc);
        var dot_found = false;
        while (std.ascii.isDigit(self.current_char) or self.current_char == '.') {
            if (self.current_char == '.') {
                if (dot_found) return LexerErrors.TooManyDotsInNumber;
                dot_found = true;
            }
            number_str.append(self.current_char);
            self.advance();
        }
    }
    pub fn next_token(self: *Lexer) !Token {
        self.skip_whitespace();

        return error.UnknwonLexerError;
    }
};

test "identifier" {
    const lexer = Lexer{ .input = "xyz abc _123", .alloc = std.testing.allocator };

    const token1 = lexer.next_token();
    const exptect1 = Token{ .type = identifier, .value = "xyz" };
    std.testing.expectEqual(token, exptect1);

    const token2 = lexer.next_token();
    const exptect2 = Token{ .type = identifier, .value = "abc" };

    const token3 = lexer.next_token();
    const exptect3 = Token{ .type = identifier, .value = "_123" };
}
