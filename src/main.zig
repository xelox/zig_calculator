const std = @import("std");
const print = std.debug.print;

const TokenCodes = enum {
    number,
    add,
    sub,
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

    pub fn get_next_char(self: *Interpreter) ?u8 {
        if (self.pos >= self.input.len - 1) return null;
        while (self.input[self.pos] == ' ' and self.pos < self.input.len - 1) {
            self.pos += 1;
        }
        if (self.pos >= self.input.len - 1) return null;

        const current_char = self.input[self.pos];
        self.pos += 1;
        return current_char;
    }

    pub fn get_next_token(self: *Interpreter) Token {
        if (self.pos > self.input.len - 1) {
            return Token{ .type = TokenCodes.eof };
        }

        var current_char: u8 = self.get_next_char() orelse return Token{ .type = TokenCodes.eof };

        if (current_char == '+') {
            return Token{ .type = TokenCodes.add };
        }

        if (current_char == '-') {
            return Token{ .type = TokenCodes.sub };
        }

        var found_a_number = false;
        var have_a_dot: bool = false;
        var str = std.ArrayList(u8).init(alloc);
        while ((std.ascii.isDigit(current_char) or current_char == '.')) {
            found_a_number = true;
            if (current_char == '.') {
                if (have_a_dot) @panic("two many dots in one number.");
                have_a_dot = true;
            }

            str.append(current_char) catch @panic("alloc failure.");
            current_char = self.get_next_char() orelse break;
        }

        if (std.mem.eql(u8, str.items, ".")) @panic("got a dot and not a number.");
        if (!found_a_number) {
            print("register contains: {s}\n", .{str.items});
            @panic("fatal error parsing token.");
        }

        self.pos -= 1;

        const value = std.fmt.parseFloat(f32, str.items) catch @panic("failed to parseFloat.");
        return Token{ .type = TokenCodes.number, .value = value };
    }

    pub fn eat(self: *Interpreter, acceptable_tokens: []const TokenCodes) void {
        print("eating token: {?} and expecting {any}\n", .{ self.current_token, acceptable_tokens });
        for (acceptable_tokens) |ok_token| {
            if (self.current_token.?.type == ok_token) {
                self.current_token = self.get_next_token();
                return;
            }
        }
        var buff: [1028]u8 = undefined;
        if (acceptable_tokens.len == 1) {
            _ = std.fmt.bufPrint(&buff, "current_token is {?} but {any} was expected", .{ self.current_token, acceptable_tokens[0] }) catch unreachable;
            @panic(&buff);
        } else {
            _ = std.fmt.bufPrint(&buff, "current token is {?} but any of {any} were expected", .{ self.current_token, acceptable_tokens }) catch unreachable;
            @panic(&buff);
        }
    }

    pub fn eval(self: *Interpreter) f32 {
        self.current_token = self.get_next_token();
        const left = self.current_token;
        self.eat(&[_]TokenCodes{TokenCodes.number});

        const op = self.current_token;
        self.eat(&[_]TokenCodes{ TokenCodes.add, TokenCodes.sub });

        const right = self.current_token;
        self.eat(&[_]TokenCodes{TokenCodes.number});

        const result = if (op.?.type == TokenCodes.add) left.?.value.? + right.?.value.? else left.?.value.? - right.?.value.?;
        return result;
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
