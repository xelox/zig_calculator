const std = @import("std");
const print = std.debug.print;

const TokenCodes = enum {
    add,
    sub,
    mul,
    div,
    lpar,
    rpar,
    number,
    eof,
};

const Token = struct {
    type: TokenCodes,
    value: ?f32 = null,

    pub fn format(self: Token, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print("Token({s}, {?d})", .{ @tagName(self.type), self.value });
    }
};

const Interpreter = struct {
    input: []u8,
    pos: usize = 0,
    current_token: ?Token = null,
    current_char: u8 = undefined,

    pub fn skip_whitespace(self: *Interpreter) void {
        while (self.current_char == ' ') {
            self.pos += 1;
            if (self.pos >= self.input.len) return;
            self.current_char = self.input[self.pos];
        }
    }

    pub fn advance(self: *Interpreter) bool {
        if (self.pos >= self.input.len) {
            print("advanced to eof\n", .{});
            self.current_char = 0;
            return false;
        }
        self.current_char = self.input[self.pos];
        self.skip_whitespace();
        self.pos += 1;
        print("advanced to {c}\n", .{self.current_char});
        return true;
    }

    pub fn number(self: *Interpreter) f32 {
        var found_dot = false;
        var number_str = std.ArrayList(u8).init(alloc);
        while (std.ascii.isDigit(self.current_char) or self.current_char == '.') {
            if (self.current_char == '.') {
                if (found_dot) @panic("two many dots in one number.");
                found_dot = true;
            }
            number_str.append(self.current_char) catch @panic("alloc error.");
            if (!self.advance()) break;
        }
        if (number_str.items.len == 0 or (number_str.items.len == 1 and number_str.items[0] == '.')) {
            @panic("error collecting number string.");
        }
        self.pos -= 1;

        return std.fmt.parseFloat(f32, number_str.items) catch @panic("error parsing number.");
    }

    pub fn get_next_token(self: *Interpreter) Token {
        if (!self.advance()) return Token{ .type = TokenCodes.eof };
        if (self.current_char == '+') return Token{ .type = TokenCodes.add };
        if (self.current_char == '-') return Token{ .type = TokenCodes.sub };
        if (self.current_char == '*') return Token{ .type = TokenCodes.mul };
        if (self.current_char == '/') return Token{ .type = TokenCodes.div };
        if (self.current_char == '(') return Token{ .type = TokenCodes.lpar };
        if (self.current_char == ')') return Token{ .type = TokenCodes.rpar };
        return Token{ .type = TokenCodes.number, .value = self.number() };
    }

    pub fn eat(self: *Interpreter, expected: TokenCodes) void {
        print("eating token: {?} and expecting {s}\n", .{ self.current_token, @tagName(expected) });
        if (self.current_token.?.type == expected) {
            self.current_token = self.get_next_token();
            return;
        }
        var buff: [1028]u8 = undefined;
        _ = std.fmt.bufPrint(&buff, "current_token is {?} but {s} was expected", .{ self.current_token, @tagName(expected) }) catch unreachable;
        @panic(&buff);
    }

    pub fn factor(self: *Interpreter) f32 {
        switch (self.current_token.?.type) {
            TokenCodes.number => {
                const value = self.current_token.?.value.?;
                self.eat(TokenCodes.number);
                return value;
            },
            TokenCodes.lpar => {
                self.eat(TokenCodes.lpar);
                const result = self.expr();
                self.eat(TokenCodes.rpar);
                return result;
            },
            else => {
                @panic("Unexpected Token");
            },
        }
    }

    pub fn term(self: *Interpreter) f32 {
        var result = self.factor();
        while (self.current_token.?.type == TokenCodes.mul or self.current_token.?.type == TokenCodes.div) {
            const token = self.current_token.?;
            switch (token.type) {
                TokenCodes.mul => {
                    self.eat(TokenCodes.mul);
                    result *= self.factor();
                },
                TokenCodes.div => {
                    self.eat(TokenCodes.div);
                    result /= self.factor();
                },
                else => unreachable,
            }
        }
        return result;
    }

    pub fn expr(self: *Interpreter) f32 {
        var result = self.term();
        while (self.current_token.?.type == TokenCodes.add or self.current_token.?.type == TokenCodes.sub) {
            const token = self.current_token.?;
            switch (token.type) {
                TokenCodes.add => {
                    self.eat(TokenCodes.add);
                    result += self.term();
                },
                TokenCodes.sub => {
                    self.eat(TokenCodes.sub);
                    result -= self.term();
                },
                else => unreachable,
            }
        }
        return result;
    }

    pub fn eval(self: *Interpreter) f32 {
        self.current_token = self.get_next_token();
        return self.expr();
    }
};

pub fn main() !void {
    defer arena.deinit();

    const argsArr = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, argsArr);

    const argsStr = try std.mem.join(alloc, " ", argsArr[1..]);

    var interpreter = Interpreter{ .input = argsStr };

    const result = interpreter.eval();

    print("{s}={d}\n", .{ argsStr, result });
}

//allocator setup
const pga = std.heap.page_allocator;
var arena = std.heap.ArenaAllocator.init(pga);
const alloc = arena.allocator();
