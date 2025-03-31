const std = @import("std");

const t = @import("token.zig");
const Rc = @import("ref_counter.zig").Rc;

pub const Error = error{
    BadTokenForNodeType,
};

pub const Num = struct { token: t.Token };
const Block = struct { children: []Node };
pub const Var = struct { token: t.Token };
pub const NoOp = struct {};

pub const AssignOp = struct {
    token: t.Token,
    left: *Node,
    right: *Node,
};

pub const BinOp = struct {
    token: t.Token,
    left: *Node,
    right: *Node,
};

pub const UnaryOp = struct {
    token: t.Token,
    operand: *Node,
};

pub const Node = union(enum) {
    number: Num,
    bin_op: BinOp,
    unary_op: UnaryOp,
    block: Block,
    assign_op: AssignOp,
    variable: Var,
    noop: NoOp,

    pub fn createNumber(token: t.Token) !Node {
        switch (token.variant()) {
            .float, .integer => {},
            else => return Error.BadTokenForNodeType,
        }
        return Node{ .number = Num{ .token = token } };
    }

    pub fn createVar(token: t.Token) !Node {
        if (token.variant() != .identifier) return Error.BadTokenForNodeType;
        return Node{ .variable = Var{ .token = token } };
    }

    pub fn createBinOp(alloc: std.mem.Allocator, token: t.Token, left: Node, right: Node) !Node {
        switch (token.variant()) {
            .add, .sub, .mul, .div => {},
            else => return Error.BadTokenForNodeType,
        }

        const left_ptr = try alloc.create(Node);
        errdefer alloc.destroy(left_ptr);
        left_ptr.* = left;

        const right_ptr = try alloc.create(Node);
        right_ptr.* = right;

        return Node{
            .bin_op = BinOp{
                .left = left_ptr,
                .right = right_ptr,
                .token = token,
            },
        };
    }

    pub fn createUnaryOp(alloc: std.mem.Allocator, token: t.Token, operand: Node) !Node {
        switch (token.variant()) {
            .add, .sub => {},
            else => return Error.BadTokenForNodeType,
        }

        const operand_ptr = try alloc.create(Node);
        operand_ptr.* = operand;

        return Node{
            .unary_op = UnaryOp{
                .operand = operand_ptr,
                .token = token,
            },
        };
    }

    pub fn createNoOp() Node {
        return Node{ .noop = .{} };
    }

    pub fn createBlock(children: []Node) !Node {
        return Node{ .block = .{ .children = children } };
    }

    pub fn createAssign(alloc: std.mem.Allocator, token: t.Token, left: Node, right: Node) !Node {
        if (token.variant() != .assign) return Error.BadTokenForNodeType;

        const left_ptr = try alloc.create(Node);
        errdefer alloc.destroy(left_ptr);
        left_ptr.* = left;

        const right_ptr = try alloc.create(Node);
        right_ptr.* = right;

        return Node{
            .assign_op = AssignOp{
                .left = left_ptr,
                .right = right_ptr,
                .token = token,
            },
        };
    }

    pub fn print(self: *const Node, writer: anytype, indent: usize) !void {
        for (0..indent) |_| {
            try writer.print("    ", .{});
        }

        switch (self.*) {
            .number => |item| {
                try writer.print("{}\n", .{item.token});
            },
            .variable => |item| {
                try writer.print("{}\n", .{item.token});
            },
            .block => |item| {
                try writer.print("Begin\n", .{});
                for (item.children) |child| {
                    try child.print(writer, indent + 1);
                }
                for (0..indent) |_| {
                    try writer.print("    ", .{});
                }
                try writer.print("End\n", .{});
            },
            .assign_op => |item| {
                try writer.print("{}\n", .{item.token});
                try item.left.print(writer, indent + 1);
                try item.right.print(writer, indent + 1);
            },
            .bin_op => |item| {
                try writer.print("{}\n", .{item.token});
                try item.left.print(writer, indent + 1);
                try item.right.print(writer, indent + 1);
            },
            .unary_op => |item| {
                try writer.print("{}\n", .{item.token});
                try item.operand.print(writer, indent + 1);
            },
            .noop => {
                try writer.print("noop\n", .{});
            },
        }
    }
};

test "AST number nodes" {
    const number_token = t.Token.createInteger(12);
    const number_node = try Node.createNumber(number_token);
    try std.testing.expectEqual(number_node.number.token.integer, 12);
}

test "AST identifier nodes" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const identifier_token = try t.Token.createIdentifier(alloc, "hello", true);
    const identifier_node = try Node.createVar(identifier_token);

    try std.testing.expectEqualSlices(u8, identifier_node.variable.token.identifier, "hello");
}

test "AST bin_op nodes" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const seven_token = t.Token.createInteger(7);
    const three_token = t.Token.createInteger(3);
    const add_token = try t.Token.createBasic(t.Variants.add);

    const seven_node = try Node.createNumber(seven_token);
    const three_node = try Node.createNumber(three_token);
    const bin_op_node = try Node.createBinOp(alloc, add_token, seven_node, three_node);

    try std.testing.expectEqual(7, bin_op_node.bin_op.left.number.token.integer);
    try std.testing.expectEqual(3, bin_op_node.bin_op.right.number.token.integer);
    try std.testing.expectEqual(t.Variants.add, bin_op_node.bin_op.token.variant());
}

test "AST unary_op nodes" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const add_token = try t.Token.createBasic(.sub);

    const five_token = t.Token.createInteger(5);
    const five_node = try Node.createNumber(five_token);

    const unnary_add_node = try Node.createUnaryOp(alloc, add_token, five_node);
    try std.testing.expectEqual(t.Variants.sub, unnary_add_node.unary_op.token);
    try std.testing.expectEqual(5, unnary_add_node.unary_op.operand.number.token.integer);

    const bad_token = try t.Token.createBasic(.mul);
    const bad_unary_op_node = Node.createUnaryOp(alloc, bad_token, five_node);
    try std.testing.expectEqual(Error.BadTokenForNodeType, bad_unary_op_node);
}

test "AST multiple layers" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const add_token = try t.Token.createBasic(.add);
    const one_token = t.Token.createInteger(1);
    const two_token = t.Token.createInteger(2);
    const three_token = t.Token.createInteger(3);
    const four_token = t.Token.createInteger(4);

    const num_node_1 = try Node.createNumber(one_token);
    const num_node_2 = try Node.createNumber(two_token);
    const num_node_3 = try Node.createNumber(three_token);
    const num_node_4 = try Node.createNumber(four_token);

    const l1 = try Node.createBinOp(alloc, add_token, num_node_1, num_node_2);
    const l2 = try Node.createBinOp(alloc, add_token, l1, num_node_3);
    const l3 = try Node.createBinOp(alloc, add_token, l2, num_node_4);

    try std.testing.expectEqual(4, l3.bin_op.right.number.token.integer);
    try std.testing.expectEqual(3, l3.bin_op.left.bin_op.right.number.token.integer);
    try std.testing.expectEqual(2, l3.bin_op.left.bin_op.left.bin_op.right.number.token.integer);
    try std.testing.expectEqual(1, l3.bin_op.left.bin_op.left.bin_op.left.number.token.integer);
}

test "AST unary_op" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const num_token = t.Token.createInteger(1);
    const minus_token = try t.Token.createBasic(t.Variants.sub);
    const plus_token = try t.Token.createBasic(t.Variants.add);

    const num_node = try Node.createNumber(num_token);

    const l1 = try Node.createUnaryOp(alloc, minus_token, num_node);
    const l2 = try Node.createUnaryOp(alloc, plus_token, l1);
    const l3 = try Node.createUnaryOp(alloc, minus_token, l2);
    const l4 = try Node.createUnaryOp(alloc, plus_token, l3);

    try std.testing.expectEqual(t.Variants.add, l4.unary_op.token.variant());
    try std.testing.expectEqual(t.Variants.sub, l4.unary_op.operand.unary_op.token.variant());
    try std.testing.expectEqual(t.Variants.add, l4.unary_op.operand.unary_op.operand.unary_op.token.variant());
    try std.testing.expectEqual(t.Variants.sub, l4.unary_op.operand.unary_op.operand.unary_op.operand.unary_op.token.variant());
}

test "AST statements" {
    // { x = 23 + 4; { y = x / 2; z = y + 4 } }
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const assign_token = try t.Token.createBasic(t.Variants.assign);
    const add_token = try t.Token.createBasic(t.Variants.add);
    const div_token = try t.Token.createBasic(t.Variants.div);
    const num_token_23 = t.Token.createInteger(23);
    const num_token_4 = t.Token.createInteger(4);
    const num_token_2 = t.Token.createInteger(2);

    const num_node_23 = try Node.createNumber(num_token_23);
    const num_node_4 = try Node.createNumber(num_token_4);
    const num_node_2 = try Node.createNumber(num_token_2);

    const x_token = try t.Token.createIdentifier(alloc, "x", true);
    const y_token = try t.Token.createIdentifier(alloc, "y", true);
    const z_token = try t.Token.createIdentifier(alloc, "z", true);

    const x_var_node = try Node.createVar(x_token);
    const y_var_node = try Node.createVar(y_token);
    const z_var_node = try Node.createVar(z_token);

    const bin_add_node = try Node.createBinOp(alloc, add_token, num_node_23, num_node_4);
    const bin_div_node = try Node.createBinOp(alloc, div_token, x_var_node, num_node_2);
    const bin_y_add_4_node = try Node.createBinOp(alloc, add_token, y_var_node, num_node_4);

    const x_assign = try Node.createAssign(alloc, assign_token, x_var_node, bin_add_node);
    const y_assign = try Node.createAssign(alloc, assign_token, y_var_node, bin_div_node);
    const z_assign = try Node.createAssign(alloc, assign_token, z_var_node, bin_y_add_4_node);

    var inner_compound_list = try alloc.alloc(Node, 2);
    inner_compound_list[0] = y_assign;
    inner_compound_list[1] = z_assign;
    const inner_compound_node = try Node.createBlock(inner_compound_list);

    var compund_list = try alloc.alloc(Node, 2);
    compund_list[0] = x_assign;
    compund_list[1] = inner_compound_node;
    const compound_node = try Node.createBlock(compund_list);

    var str = std.ArrayList(u8).init(alloc);
    try compound_node.print(str.writer(), 0);

    const expected =
        \\Begin
        \\    Simb(assign)
        \\        Id(x)
        \\        Op(add)
        \\            Int(23)
        \\            Int(4)
        \\    Begin
        \\        Simb(assign)
        \\            Id(y)
        \\            Op(div)
        \\                Id(x)
        \\                Int(2)
        \\        Simb(assign)
        \\            Id(z)
        \\            Op(add)
        \\                Id(y)
        \\                Int(4)
        \\    End
        \\End
        \\
    ;
    try std.testing.expectEqualSlices(u8, expected, str.items);
}
