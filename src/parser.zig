const std = @import("std");
const Allocator = std.mem.Allocator;
const Arena = std.heap.ArenaAllocator;
const panic = std.debug.panic;

const Lexer = @import("lexer.zig").Lexer;
const Rc = @import("ref_counter.zig").Rc;
const RcNode = Rc(AST.Node);

const AST = @import("AST.zig");
const t = @import("token.zig");
const l = @import("lexer.zig");

const Error = error{
    UnexpectedToken,
};

pub const Parser = struct {
    lexer: Lexer = undefined,
    current_token: t.Token = undefined,
    alloc: std.mem.Allocator = undefined,

    pub fn init(arena: *Arena) Parser {
        const alloc = arena.allocator();
        const lexer = Lexer.init(arena);
        return .{ .lexer = lexer, .alloc = alloc };
    }

    pub fn parse(self: *Parser, input: []const u8) !AST.Node {
        self.lexer.set_input(input);
        self.current_token = try self.lexer.nextToken();
        return self.program();
    }

    fn eat(self: *Parser, variant: t.Variants) !void {
        if (self.current_token.variant() == variant) {
            self.current_token = try self.lexer.nextToken();
        } else {
            return Error.UnexpectedToken;
        }
    }

    fn program(self: *Parser) !AST.Node {
        const node = try self.block();
        try self.eat(.eof);
        return node;
    }

    fn block(self: *Parser) !AST.Node {
        try self.eat(.begin);

        var list = std.ArrayList(AST.Node).init(self.alloc);
        try list.append(try self.statement());
        while (self.current_token.variant() == .semicolon) {
            try self.eat(.semicolon);
            try list.append(try self.statement());
        }
        if (self.current_token.variant() != .end) return Error.UnexpectedToken;

        try self.eat(.end);

        return AST.Node.createBlock(try list.toOwnedSlice());
    }

    fn statement(self: *Parser) anyerror!AST.Node {
        return switch (self.current_token) {
            .begin => self.block(),
            .identifier => self.assign_statement(),
            else => AST.Node.createNoOp(),
        };
    }

    fn assign_statement(self: *Parser) !AST.Node {
        const left = try self.variable();
        const token = self.current_token;

        try self.eat(.assign);

        const right = try self.expr();
        return AST.Node.createAssign(self.alloc, token, left, right);
    }

    fn variable(self: *Parser) !AST.Node {
        const node = try AST.Node.createVar(self.current_token);
        try self.eat(.identifier);
        return node;
    }

    fn factor(self: *Parser) !AST.Node {
        const token = self.current_token;

        switch (token.variant()) {
            .add, .sub => {
                try self.eat(token.variant());
                return AST.Node.createUnaryOp(self.alloc, token, try self.factor());
            },
            .float => {
                try self.eat(.float);
                return AST.Node.createNumber(token);
            },
            .integer => {
                try self.eat(.integer);
                return AST.Node.createNumber(token);
            },
            .identifier => {
                return self.variable();
            },
            .lpar => {
                try self.eat(.lpar);
                const node = try self.expr();
                try self.eat(.rpar);
                return node;
            },
            else => panic("expected number token or lpar token, but got: {s}", .{@tagName(token.variant())}),
        }
    }

    fn term(self: *Parser) !AST.Node {
        var node = try self.factor();

        while (switch (self.current_token.variant()) {
            .mul, .div => true,
            else => false,
        }) {
            const token = self.current_token;
            try self.eat(token.variant());
            node = try AST.Node.createBinOp(self.alloc, token, node, try self.factor());
        }

        return node;
    }

    fn expr(self: *Parser) anyerror!AST.Node {
        var node = try self.term();

        while (switch (self.current_token.variant()) {
            .add, .sub => true,
            else => false,
        }) {
            const token = self.current_token;
            try self.eat(token.variant());
            node = try AST.Node.createBinOp(self.alloc, token, node, try self.term());
        }

        return node;
    }
};

test "unary test" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var parser = Parser.init(&arena);
    const result = try parser.parse("{x = ---8}");

    const x_token = try t.Token.createIdentifier(alloc, "x", true);
    const assign_token = try t.Token.createBasic(.assign);
    const minus_token = try t.Token.createBasic(.sub);
    const num_token = t.Token.createFloat(8);

    const x_node = try AST.Node.createVar(x_token);
    const num_node = try AST.Node.createNumber(num_token);

    const unary_1 = try AST.Node.createUnaryOp(alloc, minus_token, num_node);
    const unary_2 = try AST.Node.createUnaryOp(alloc, minus_token, unary_1);
    const unary_3 = try AST.Node.createUnaryOp(alloc, minus_token, unary_2);

    const assign_node = try AST.Node.createAssign(alloc, assign_token, x_node, unary_3);

    const statement_list = try alloc.alloc(AST.Node, 1);
    statement_list[0] = assign_node;
    const program = try AST.Node.createBlock(statement_list);

    var expected_str = std.ArrayList(u8).init(alloc);
    try program.print(expected_str.writer(), 0);

    var actual_str = std.ArrayList(u8).init(alloc);
    try result.print(actual_str.writer(), 0);

    try std.testing.expectEqualSlices(u8, expected_str.items, actual_str.items);
}

test "simple test" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var parser = Parser.init(&arena);
    const result = try parser.parse("{x = 2 + 7 * 3}");

    const x_token = try t.Token.createIdentifier(alloc, "x", true);
    const assign_token = try t.Token.createBasic(.assign);
    const two_token = t.Token.createFloat(2);
    const add_token = try t.Token.createBasic(.add);
    const seven_token = t.Token.createFloat(7);
    const mul_token = try t.Token.createBasic(.mul);
    const three_token = t.Token.createFloat(3);

    const x_node = try AST.Node.createVar(x_token);
    const seven_node = try AST.Node.createNumber(seven_token);
    const three_node = try AST.Node.createNumber(three_token);
    const bin_mul_node = try AST.Node.createBinOp(alloc, mul_token, seven_node, three_node);
    const two_node = try AST.Node.createNumber(two_token);
    const bin_add_node = try AST.Node.createBinOp(alloc, add_token, two_node, bin_mul_node);

    const x_assign = try AST.Node.createAssign(alloc, assign_token, x_node, bin_add_node);

    const statement_list = try alloc.alloc(AST.Node, 1);
    statement_list[0] = x_assign;
    const program_node = try AST.Node.createBlock(statement_list);

    var expected_str = std.ArrayList(u8).init(alloc);
    try program_node.print(expected_str.writer(), 0);

    var actual_str = std.ArrayList(u8).init(alloc);
    try result.print(actual_str.writer(), 0);

    try std.testing.expectEqualSlices(u8, expected_str.items, actual_str.items);
}

test "var used as value" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var parser = Parser.init(&arena);
    const result = try parser.parse("{x = y + 2}");

    const x_token = try t.Token.createIdentifier(alloc, "x", true);
    const y_token = try t.Token.createIdentifier(alloc, "y", true);
    const assign_token = try t.Token.createBasic(.assign);
    const two_token = t.Token.createFloat(2);
    const add_token = try t.Token.createBasic(.add);

    const x_node = try AST.Node.createVar(x_token);
    const y_node = try AST.Node.createVar(y_token);
    const two_node = try AST.Node.createNumber(two_token);
    const bin_add_node = try AST.Node.createBinOp(alloc, add_token, y_node, two_node);
    const x_assign = try AST.Node.createAssign(alloc, assign_token, x_node, bin_add_node);

    const statement_list = try alloc.alloc(AST.Node, 1);
    statement_list[0] = x_assign;
    const program_node = try AST.Node.createBlock(statement_list);

    var expected_str = std.ArrayList(u8).init(alloc);
    try program_node.print(expected_str.writer(), 0);

    var actual_str = std.ArrayList(u8).init(alloc);
    try result.print(actual_str.writer(), 0);

    try std.testing.expectEqualSlices(u8, expected_str.items, actual_str.items);
}

test "segfault haunt" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var parser = Parser.init(&arena);
    const result = try parser.parse("{x = y + 2}");
    try std.testing.expectEqualSlices(u8, "x", result.block.children[0].assign_op.left.variable.token.identifier);
    try std.testing.expectEqualSlices(u8, "y", result.block.children[0].assign_op.right.bin_op.left.variable.token.identifier);

    var hash_map = std.StringHashMap(bool).init(alloc);

    const x = result.block.children[0].assign_op.left.variable.token.identifier;
    const y = result.block.children[0].assign_op.right.bin_op.left.variable.token.identifier;

    try hash_map.put(x, true);
    try hash_map.put(y, true);

    try std.testing.expectEqual(true, hash_map.get(x) orelse false);
    try std.testing.expectEqual(true, hash_map.get(y) orelse false);
}
