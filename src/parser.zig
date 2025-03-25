const std = @import("std");
const Allocator = std.mem.Allocator;
const panic = std.debug.panic;

const Lexer = @import("lexer.zig").Lexer;
const Rc = @import("ref_counter.zig").Rc;
const RcNode = Rc(AST.Node);

const AST = @import("AST.zig");
const t = @import("token.zig");

const Error = error{
    UnexpectedToken,
};

pub const Parser = struct {
    lexer: Lexer = undefined,
    current_token: t.Token = undefined,
    alloc: std.mem.Allocator,

    fn eat(self: *Parser, variant: t.Variants) void {
        if (self.current_token.variant() == variant) {
            self.current_token.destroy(self.alloc);
            self.current_token = self.lexer.nextToken() catch |e| panic("{any}", .{e});
        } else {
            return panic("Unexpected Token", .{});
        }
    }

    fn factor(self: *Parser) AST.Node {
        const token = self.current_token.clone();
        defer token.destroy(self.alloc);

        switch (token.variant()) {
            .add, .sub => {
                self.eat(token.variant());
                const child = self.factor();
                defer child.destroy(self.alloc);
                return AST.Node.createUnaryOp(self.alloc, token, child) catch |e| panic("{any}", .{e});
            },
            .number => {
                self.eat(.number);
                return AST.Node.createNumber(token) catch |e| panic("{any}", .{e});
            },
            .lpar => {
                self.eat(.lpar);
                const node = self.expr();
                self.eat(.rpar);
                return node;
            },
            else => panic("expected number token or lpar token, but got: {s}", .{@tagName(token.variant())}),
        }
    }

    fn term(self: *Parser) AST.Node {
        var node = self.factor();

        while (switch (self.current_token.variant()) {
            .mul, .div => true,
            else => false,
        }) {
            const token = self.current_token.clone();
            defer token.destroy(self.alloc);
            self.eat(token.variant());

            const left = node;
            defer left.destroy(self.alloc);

            const right = self.factor();
            defer right.destroy(self.alloc);

            node = AST.Node.createBinOp(self.alloc, token, left, right) catch |e| panic("{any}", .{e});
        }

        return node;
    }

    fn expr(self: *Parser) AST.Node {
        var node = self.term();

        while (switch (self.current_token.variant()) {
            .add, .sub => true,
            else => false,
        }) {
            const token = self.current_token.clone();
            defer token.destroy(self.alloc);
            self.eat(token.variant());

            const left = node;
            defer left.destroy(self.alloc);

            const right = self.term();
            defer right.destroy(self.alloc);

            node = AST.Node.createBinOp(self.alloc, token, left, right) catch |e| panic("{any}", .{e});
        }

        return node;
    }

    pub fn parse(self: *Parser, input: []const u8) AST.Node {
        self.lexer = Lexer{ .input = input, .alloc = self.alloc };
        self.current_token = self.lexer.nextToken() catch |e| panic("{any}", .{e});
        return self.expr();
    }
};

test "unary test" {
    const alloc = std.testing.allocator;
    var parser = Parser{ .alloc = alloc };
    const root = parser.parse("---8");
    defer root.destroy(alloc);

    const num_token = try t.Token.createNumber(alloc, 8);
    defer num_token.destroy(alloc);

    const num_node = try AST.Node.createNumber(num_token);
    defer num_node.destroy(alloc);

    const minus_token = try t.Token.createBasic(t.Variants.sub);
    defer minus_token.destroy(alloc);

    const unary_1 = try AST.Node.createUnaryOp(alloc, minus_token, num_node);
    defer unary_1.destroy(alloc);

    const unary_2 = try AST.Node.createUnaryOp(alloc, minus_token, unary_1);
    defer unary_2.destroy(alloc);

    const unary_3 = try AST.Node.createUnaryOp(alloc, minus_token, unary_2);
    defer unary_3.destroy(alloc);

    var expected_str = std.ArrayList(u8).init(alloc);
    defer expected_str.deinit();
    try unary_3.print(expected_str.writer(), 0);

    var actual_str = std.ArrayList(u8).init(alloc);
    defer actual_str.deinit();
    try root.print(actual_str.writer(), 0);

    try std.testing.expectEqualSlices(u8, expected_str.items, actual_str.items);
}

test "simple test" {
    const alloc = std.testing.allocator;
    const input = "2 + 7 * 3";

    var parser = Parser{ .alloc = alloc };

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

    var expected_str = std.ArrayList(u8).init(alloc);
    defer expected_str.deinit();

    try bin_add_node.print(expected_str.writer(), 0);

    // Parse Result:

    const root = parser.parse(input);
    defer root.destroy(alloc);

    var actual_str = std.ArrayList(u8).init(alloc);
    defer actual_str.deinit();
    try root.print(actual_str.writer(), 0);

    try std.testing.expectEqualSlices(u8, expected_str.items, actual_str.items);
}
