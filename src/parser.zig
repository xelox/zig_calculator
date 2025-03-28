const std = @import("std");
const Allocator = std.mem.Allocator;
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
    alloc: std.mem.Allocator,

    fn eat(self: *Parser, variant: t.Variants) !void {
        if (self.current_token.variant() == variant) {
            self.current_token.destroy(self.alloc);
            self.current_token = try self.lexer.nextToken();
        } else {
            return panic("Unexpected Token", .{});
        }
    }

    fn program(self: *Parser) !AST.Node {
        const node = try self.compund_statement();
        try self.eat(.eof);
        return node;
    }

    fn compund_statement(self: *Parser) !AST.Node {
        try self.eat(.begin);
        const nodes = try self.statement_list();
        try self.eat(.end);
        return AST.Node.createCompound(nodes);
    }

    fn statement_list(self: *Parser) ![]AST.Node {
        var list = std.ArrayList(AST.Node).init(self.alloc);
        errdefer {
            for (list.items) |*child| {
                child.destroy(self.alloc);
            }
            list.deinit();
        }

        try list.append(try self.statement());
        while (self.current_token.variant() == .semicolon) {
            try self.eat(.semicolon);
            try list.append(try self.statement());
        }

        if (self.current_token.variant() == .identifier) return Error.UnexpectedToken;
        return list.toOwnedSlice();
    }

    fn statement(self: *Parser) anyerror!AST.Node {
        return switch (self.current_token) {
            .begin => self.compund_statement(),
            .identifier => self.assign_statement(),
            else => AST.Node.createNoOp(),
        };
    }

    fn assign_statement(self: *Parser) !AST.Node {
        const left = try self.variable();
        defer left.destroy(self.alloc);

        const token = self.current_token.clone();
        try self.eat(.assign);

        const right = try self.expr();
        defer right.destroy(self.alloc);

        return AST.Node.createAssign(self.alloc, token, left, right);
    }

    fn variable(self: *Parser) !AST.Node {
        const node = AST.Node.createVar(self.current_token);
        try self.eat(.identifier);
        return node;
    }

    fn factor(self: *Parser) !AST.Node {
        const token = self.current_token.clone();
        defer token.destroy(self.alloc);

        switch (token.variant()) {
            .add, .sub => {
                try self.eat(token.variant());
                const child = try self.factor();
                defer child.destroy(self.alloc);
                return AST.Node.createUnaryOp(self.alloc, token, child);
            },
            .number => {
                try self.eat(.number);
                return AST.Node.createNumber(token);
            },
            .identifier => {
                try self.eat(.identifier);
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
            const token = self.current_token.clone();
            defer token.destroy(self.alloc);
            try self.eat(token.variant());

            const left = node;
            defer left.destroy(self.alloc);

            const right = try self.factor();
            defer right.destroy(self.alloc);

            node = try AST.Node.createBinOp(self.alloc, token, left, right);
        }

        return node;
    }

    fn expr(self: *Parser) anyerror!AST.Node {
        var node = try self.term();

        while (switch (self.current_token.variant()) {
            .add, .sub => true,
            else => false,
        }) {
            const token = self.current_token.clone();
            defer token.destroy(self.alloc);
            try self.eat(token.variant());

            const left = node;
            defer left.destroy(self.alloc);

            const right = try self.term();
            defer right.destroy(self.alloc);

            node = try AST.Node.createBinOp(self.alloc, token, left, right);
        }

        return node;
    }

    pub fn parse(self: *Parser, input: []const u8) !AST.Node {
        self.lexer = Lexer{ .input = input, .alloc = self.alloc };
        self.current_token = try self.lexer.nextToken();
        return self.program();
    }
};

test "unary test" {
    const alloc = std.testing.allocator;
    var parser = Parser{ .alloc = alloc };
    const root = try parser.parse("{x = ---8}");
    defer root.destroy(alloc);

    const x_token = try t.Token.createIdentifier(alloc, "x", true);
    defer x_token.destroy(alloc);

    const assign_token = try t.Token.createBasic(.assign);
    assign_token.destroy(alloc);

    const num_token = try t.Token.createNumber(alloc, 8);
    defer num_token.destroy(alloc);

    const num_node = try AST.Node.createNumber(num_token);
    defer num_node.destroy(alloc);

    const minus_token = try t.Token.createBasic(.sub);
    defer minus_token.destroy(alloc);

    const unary_1 = try AST.Node.createUnaryOp(alloc, minus_token, num_node);
    defer unary_1.destroy(alloc);

    const unary_2 = try AST.Node.createUnaryOp(alloc, minus_token, unary_1);
    defer unary_2.destroy(alloc);

    const unary_3 = try AST.Node.createUnaryOp(alloc, minus_token, unary_2);
    defer unary_3.destroy(alloc);

    const x_node = try AST.Node.createVar(x_token);
    defer x_node.destroy(alloc);

    const assign_node = try AST.Node.createAssign(alloc, assign_token, x_node, unary_3);

    const statement_list = try alloc.alloc(AST.Node, 1);
    statement_list[0] = assign_node;
    const program = try AST.Node.createCompound(statement_list);
    defer program.destroy(alloc);

    var expected_str = std.ArrayList(u8).init(alloc);
    defer expected_str.deinit();
    try program.print(expected_str.writer(), 0);

    var actual_str = std.ArrayList(u8).init(alloc);
    defer actual_str.deinit();
    try root.print(actual_str.writer(), 0);

    try std.testing.expectEqualSlices(u8, expected_str.items, actual_str.items);
}

test "simple test" {
    const alloc = std.testing.allocator;
    const input = "{x = 2 + 7 * 3}";

    var parser = Parser{ .alloc = alloc };

    // ID (x)
    const x_token = try t.Token.createIdentifier(alloc, "x", true);
    defer x_token.destroy(alloc);

    // Assign (=)
    const assign_token = try t.Token.createBasic(.assign);
    defer assign_token.destroy(alloc);

    // TWO (2)
    const two_token = try t.Token.createNumber(alloc, 2);
    defer two_token.destroy(alloc);

    // ADD (+)
    const add_token = try t.Token.createBasic(.add);
    defer add_token.destroy(alloc);

    // SEVEN (7)
    const seven_token = try t.Token.createNumber(alloc, 7);
    defer seven_token.destroy(alloc);

    // MUL (*)
    const mul_token = try t.Token.createBasic(.mul);
    defer mul_token.destroy(alloc);

    // THREE (3)
    const three_token = try t.Token.createNumber(alloc, 3);
    defer three_token.destroy(alloc);

    //
    // ---------NODES----------
    //

    const x_node = try AST.Node.createVar(x_token);
    defer x_node.destroy(alloc);

    // SEVEN (7)
    const seven_node = try AST.Node.createNumber(seven_token);
    defer seven_node.destroy(alloc);

    // THREE (3)
    const three_node = try AST.Node.createNumber(three_token);
    defer three_node.destroy(alloc);

    // MUL (7 * 3) -> FACTOR
    const bin_mul_node = try AST.Node.createBinOp(alloc, mul_token, seven_node, three_node);
    defer bin_mul_node.destroy(alloc);

    // TWO (2)
    const two_node = try AST.Node.createNumber(two_token);
    defer two_node.destroy(alloc);

    // ADD (2 + FACTOR)
    const bin_add_node = try AST.Node.createBinOp(alloc, add_token, two_node, bin_mul_node);
    defer bin_add_node.destroy(alloc);

    const x_assign = try AST.Node.createAssign(alloc, assign_token, x_node, bin_add_node);
    // x_assign's ownership will be given to program_node, without cloning, so no destroying is needed.

    const statement_list = try alloc.alloc(AST.Node, 1);
    statement_list[0] = x_assign;
    const program_node = try AST.Node.createCompound(statement_list);
    defer program_node.destroy(alloc);

    var expected_str = std.ArrayList(u8).init(alloc);
    defer expected_str.deinit();

    try program_node.print(expected_str.writer(), 0);

    // Parse Result:

    const root = try parser.parse(input);
    defer root.destroy(alloc);

    var actual_str = std.ArrayList(u8).init(alloc);
    defer actual_str.deinit();
    try root.print(actual_str.writer(), 0);

    try std.testing.expectEqualSlices(u8, expected_str.items, actual_str.items);
}
