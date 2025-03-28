const std = @import("std");

const t = @import("token.zig");
const Rc = @import("ref_counter.zig").Rc;

pub const Error = error{
    BadTokenForNodeType,
};

pub const Num = struct { token: t.Token };
const Compund = struct { children: []Node };
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
    // zig fmt: off
    number: Num,            // [x]
    bin_op: BinOp,          // [x]
    unary_op: UnaryOp,      // [x]
    compound: Compund,      // [x]
    assign_op: AssignOp,    // [x]
    variable: Var,          // [x]
    noop: NoOp,             // [x]
    // zig fmt: on

    pub fn createNumber(token: t.Token) !Node {
        if (token.variant() != t.Variants.number) return Error.BadTokenForNodeType;
        return Node{ .number = Num{ .token = token.clone() } };
    }

    pub fn createVar(token: t.Token) !Node {
        if (token.variant() != t.Variants.identifier) return Error.BadTokenForNodeType;
        return Node{ .variable = Var{ .token = token.clone() } };
    }

    pub fn createBinOp(alloc: std.mem.Allocator, token: t.Token, left: Node, right: Node) !Node {
        switch (token.variant()) {
            t.Variants.add, t.Variants.sub, t.Variants.mul, t.Variants.div => {},
            else => return Error.BadTokenForNodeType,
        }

        const left_ptr = try alloc.create(Node);
        errdefer alloc.destroy(left_ptr);
        left_ptr.* = try left.clone(alloc);

        const right_ptr = try alloc.create(Node);
        errdefer alloc.destroy(right_ptr);
        right_ptr.* = try right.clone(alloc);

        return Node{
            .bin_op = BinOp{
                .left = left_ptr,
                .right = right_ptr,
                .token = token.clone(),
            },
        };
    }

    pub fn createUnaryOp(alloc: std.mem.Allocator, token: t.Token, operand: Node) !Node {
        switch (token.variant()) {
            .add, .sub => {},
            else => return Error.BadTokenForNodeType,
        }

        const operand_ptr = try alloc.create(Node);
        errdefer alloc.destroy(operand_ptr);

        operand_ptr.* = try operand.clone(alloc);

        return Node{
            .unary_op = UnaryOp{
                .operand = operand_ptr,
                .token = token.clone(),
            },
        };
    }

    pub fn createNoOp() Node {
        return Node{ .noop = .{} };
    }

    /// Takes ownership of the children slice
    pub fn createCompound(children: []Node) !Node {
        return Node{ .compound = .{ .children = children } };
    }

    pub fn createAssign(alloc: std.mem.Allocator, token: t.Token, left: Node, right: Node) !Node {
        switch (token.variant()) {
            .assign => {},
            else => return Error.BadTokenForNodeType,
        }

        const left_ptr = try alloc.create(Node);
        errdefer alloc.destroy(left_ptr);
        left_ptr.* = try left.clone(alloc);

        const right_ptr = try alloc.create(Node);
        errdefer alloc.destroy(right_ptr);
        right_ptr.* = try right.clone(alloc);

        return Node{
            .assign_op = AssignOp{
                .left = left_ptr,
                .right = right_ptr,
                .token = token.clone(),
            },
        };
    }

    pub fn clone(self: *const Node, alloc: std.mem.Allocator) !Node {
        switch (self.*) {
            .compound => |item| {
                const slice = try alloc.alloc(Node, item.children.len);
                errdefer alloc.free(slice);

                for (slice, item.children) |*dest, *src| {
                    dest.* = try src.clone(alloc);
                }
                return Node{ .compound = .{ .children = slice } };
            },
            .number => |item| {
                return Node{ .number = .{ .token = item.token.clone() } };
            },
            .variable => |item| {
                return Node{ .variable = .{ .token = item.token.clone() } };
            },
            .assign_op => |item| {
                const left_ptr = try alloc.create(Node);
                errdefer alloc.destroy(left_ptr);
                left_ptr.* = try item.left.clone(alloc);

                const right_ptr = try alloc.create(Node);
                errdefer alloc.destroy(right_ptr);
                right_ptr.* = try item.right.clone(alloc);

                return Node{ .assign_op = AssignOp{
                    .token = item.token.clone(),
                    .left = left_ptr,
                    .right = right_ptr,
                } };
            },
            .bin_op => |item| {
                const left_ptr = try alloc.create(Node);
                errdefer alloc.destroy(left_ptr);
                left_ptr.* = try item.left.clone(alloc);

                const right_ptr = try alloc.create(Node);
                errdefer alloc.destroy(right_ptr);
                right_ptr.* = try item.right.clone(alloc);

                return Node{ .bin_op = BinOp{
                    .token = item.token.clone(),
                    .left = left_ptr,
                    .right = right_ptr,
                } };
            },
            .unary_op => |item| {
                const operand_ptr = try alloc.create(Node);
                errdefer alloc.destroy(operand_ptr);
                operand_ptr.* = try item.operand.clone(alloc);

                return Node{ .unary_op = UnaryOp{
                    .token = item.token.clone(),
                    .operand = operand_ptr,
                } };
            },
            .noop => {
                return Node{ .noop = NoOp{} };
            },
        }
    }

    pub fn destroy(self: *const Node, alloc: std.mem.Allocator) void {
        switch (self.*) {
            .compound => |item| {
                for (item.children) |child| {
                    child.destroy(alloc);
                }
                alloc.free(item.children);
            },
            .bin_op => |item| {
                item.token.destroy(alloc);
                item.left.destroy(alloc);
                item.right.destroy(alloc);
                alloc.destroy(item.left);
                alloc.destroy(item.right);
            },
            .assign_op => |item| {
                item.token.destroy(alloc);
                item.left.destroy(alloc);
                item.right.destroy(alloc);
                alloc.destroy(item.left);
                alloc.destroy(item.right);
            },
            .unary_op => |item| {
                item.token.destroy(alloc);
                item.operand.destroy(alloc);
                alloc.destroy(item.operand);
            },
            .number => |item| item.token.destroy(alloc),
            .variable => |item| item.token.destroy(alloc),
            .noop => {},
        }
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
            .compound => |item| {
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
    const alloc = std.testing.allocator;

    const number_token = try t.Token.createNumber(alloc, 12);
    defer number_token.destroy(alloc);

    const number_node = try Node.createNumber(number_token);
    defer number_node.destroy(alloc);

    const clone_1 = try number_node.clone(alloc);
    defer clone_1.destroy(alloc);

    const clone_2 = try number_node.clone(alloc);
    defer clone_2.destroy(alloc);

    const clone_3 = try number_node.clone(alloc);
    defer clone_3.destroy(alloc);
}

test "AST identifier nodes" {
    const alloc = std.testing.allocator;

    const identifier_token = try t.Token.createIdentifier(alloc, "hello", true);
    defer identifier_token.destroy(alloc);

    const identifier_node = try Node.createVar(identifier_token);
    defer identifier_node.destroy(alloc);

    const clone_1 = try identifier_node.clone(alloc);
    defer clone_1.destroy(alloc);

    const clone_2 = try identifier_node.clone(alloc);
    defer clone_2.destroy(alloc);

    const clone_3 = try identifier_node.clone(alloc);
    defer clone_3.destroy(alloc);
}

test "AST bin_op nodes" {
    const alloc = std.testing.allocator;

    const seven_token = try t.Token.createNumber(alloc, 7);
    defer seven_token.destroy(alloc);

    const three_token = try t.Token.createNumber(alloc, 3);
    defer three_token.destroy(alloc);

    const add_token = try t.Token.createBasic(t.Variants.add);
    defer add_token.destroy(alloc);

    const seven_node = try Node.createNumber(seven_token);
    defer seven_node.destroy(alloc);

    const three_node = try Node.createNumber(three_token);
    defer three_node.destroy(alloc);

    const seven_add_three_node = try Node.createBinOp(alloc, add_token, seven_node, three_node);
    defer seven_add_three_node.destroy(alloc);

    const clone_1 = try seven_add_three_node.clone(alloc);
    defer clone_1.destroy(alloc);

    const clone_2 = try seven_add_three_node.clone(alloc);
    defer clone_2.destroy(alloc);

    const clone_3 = try seven_add_three_node.clone(alloc);
    defer clone_3.destroy(alloc);
}

test "AST unary_op nodes" {
    const alloc = std.testing.allocator;

    const add_token = try t.Token.createBasic(t.Variants.add);
    defer add_token.destroy(alloc);

    const five_token = try t.Token.createNumber(alloc, 5);
    defer five_token.destroy(alloc);

    const five_node = try Node.createNumber(five_token);
    defer five_node.destroy(alloc);

    const unnary_add_node = try Node.createUnaryOp(alloc, add_token, five_node);
    defer unnary_add_node.destroy(alloc);

    const clone_1 = try unnary_add_node.clone(alloc);
    defer clone_1.destroy(alloc);

    const clone_2 = try unnary_add_node.clone(alloc);
    defer clone_2.destroy(alloc);
}

test "AST multiple layers" {
    const alloc = std.testing.allocator;

    const add_token = try t.Token.createBasic(.add);
    defer add_token.destroy(alloc);

    const one_token = try t.Token.createNumber(alloc, 1);
    defer one_token.destroy(alloc);

    const two_token = try t.Token.createNumber(alloc, 2);
    defer two_token.destroy(alloc);

    const three_token = try t.Token.createNumber(alloc, 3);
    defer three_token.destroy(alloc);

    const four_token = try t.Token.createNumber(alloc, 4);
    defer four_token.destroy(alloc);

    const num_node_1 = try Node.createNumber(one_token);
    defer num_node_1.destroy(alloc);

    const num_node_2 = try Node.createNumber(two_token);
    defer num_node_2.destroy(alloc);

    const num_node_3 = try Node.createNumber(three_token);
    defer num_node_3.destroy(alloc);

    const num_node_4 = try Node.createNumber(four_token);
    defer num_node_4.destroy(alloc);

    const l1 = try Node.createBinOp(alloc, add_token, num_node_1, num_node_2);
    defer l1.destroy(alloc);

    const l2 = try Node.createBinOp(alloc, add_token, l1, num_node_3);
    defer l2.destroy(alloc);

    const l3 = try Node.createBinOp(alloc, add_token, l2, num_node_4);
    defer l3.destroy(alloc);

    try std.testing.expectEqual(4, try l3.bin_op.right.number.token.getNumber());
    try std.testing.expectEqual(3, try l3.bin_op.left.bin_op.right.number.token.getNumber());
    try std.testing.expectEqual(2, try l3.bin_op.left.bin_op.left.bin_op.right.number.token.getNumber());
    try std.testing.expectEqual(1, try l3.bin_op.left.bin_op.left.bin_op.left.number.token.getNumber());
}

test "AST unary_op" {
    const alloc = std.testing.allocator;

    const num_token = try t.Token.createNumber(alloc, 1);
    defer num_token.destroy(alloc);

    const minus_token = try t.Token.createBasic(t.Variants.sub);
    defer minus_token.destroy(alloc);

    const plus_token = try t.Token.createBasic(t.Variants.add);
    defer plus_token.destroy(alloc);

    const num_node = try Node.createNumber(num_token);
    defer num_node.destroy(alloc);

    const l1 = try Node.createUnaryOp(alloc, minus_token, num_node);
    defer l1.destroy(alloc);

    const l2 = try Node.createUnaryOp(alloc, plus_token, l1);
    defer l2.destroy(alloc);

    const l3 = try Node.createUnaryOp(alloc, minus_token, l2);
    defer l3.destroy(alloc);

    const l4 = try Node.createUnaryOp(alloc, plus_token, l3);
    defer l4.destroy(alloc);

    try std.testing.expectEqual(t.Variants.add, l4.unary_op.token.variant());
    try std.testing.expectEqual(t.Variants.sub, l4.unary_op.operand.unary_op.token.variant());
    try std.testing.expectEqual(t.Variants.add, l4.unary_op.operand.unary_op.operand.unary_op.token.variant());
    try std.testing.expectEqual(t.Variants.sub, l4.unary_op.operand.unary_op.operand.unary_op.operand.unary_op.token.variant());
}

test "AST statements" {
    const alloc = std.testing.allocator;
    // { x = 23 + 4; { y = x / 2; z = y + 4 } }

    const assign_token = try t.Token.createBasic(t.Variants.assign);
    defer assign_token.destroy(alloc);

    const add_token = try t.Token.createBasic(t.Variants.add);
    defer add_token.destroy(alloc);

    const div_token = try t.Token.createBasic(t.Variants.div);
    defer div_token.destroy(alloc);

    const num_token_23 = try t.Token.createNumber(alloc, 23);
    defer num_token_23.destroy(alloc);
    const num_node_23 = try Node.createNumber(num_token_23);
    defer num_node_23.destroy(alloc);

    const num_token_4 = try t.Token.createNumber(alloc, 4);
    defer num_token_4.destroy(alloc);
    const num_node_4 = try Node.createNumber(num_token_4);
    defer num_node_4.destroy(alloc);

    const num_token_2 = try t.Token.createNumber(alloc, 2);
    defer num_token_2.destroy(alloc);
    const num_node_2 = try Node.createNumber(num_token_2);
    defer num_node_2.destroy(alloc);

    const x_token = try t.Token.createIdentifier(alloc, "x", true);
    defer x_token.destroy(alloc);

    const y_token = try t.Token.createIdentifier(alloc, "y", true);
    defer y_token.destroy(alloc);

    const z_token = try t.Token.createIdentifier(alloc, "z", true);
    defer z_token.destroy(alloc);

    const x_var_node = try Node.createVar(x_token);
    defer x_var_node.destroy(alloc);

    const y_var_node = try Node.createVar(y_token);
    defer y_var_node.destroy(alloc);

    const z_var_node = try Node.createVar(z_token);
    defer z_var_node.destroy(alloc);

    const bin_add_node = try Node.createBinOp(alloc, add_token, num_node_23, num_node_4);
    defer bin_add_node.destroy(alloc);

    const bin_div_node = try Node.createBinOp(alloc, div_token, x_var_node, num_node_2);
    defer bin_div_node.destroy(alloc);

    const bin_y_add_4_node = try Node.createBinOp(alloc, add_token, y_var_node, num_node_4);
    defer bin_y_add_4_node.destroy(alloc);

    const x_assign = try Node.createAssign(alloc, assign_token, x_var_node, bin_add_node);
    defer x_assign.destroy(alloc);

    const y_assign = try Node.createAssign(alloc, assign_token, y_var_node, bin_div_node);
    defer y_assign.destroy(alloc);

    const z_assign = try Node.createAssign(alloc, assign_token, z_var_node, bin_y_add_4_node);
    defer z_assign.destroy(alloc);

    var inner_compound_list = try alloc.alloc(Node, 2);
    inner_compound_list[0] = try y_assign.clone(alloc);
    inner_compound_list[1] = try z_assign.clone(alloc);
    const inner_compound_node = try Node.createCompound(inner_compound_list);
    defer inner_compound_node.destroy(alloc);

    var compund_list = try alloc.alloc(Node, 2);
    compund_list[0] = try x_assign.clone(alloc);
    compund_list[1] = try inner_compound_node.clone(alloc);
    const compound_node = try Node.createCompound(compund_list);
    defer compound_node.destroy(alloc);

    const compound_clone = try compound_node.clone(alloc);
    defer compound_clone.destroy(alloc);

    var str_1 = std.ArrayList(u8).init(alloc);
    defer str_1.deinit();
    try compound_node.print(str_1.writer(), 0);

    var str_2 = std.ArrayList(u8).init(alloc);
    defer str_2.deinit();
    try compound_clone.print(str_2.writer(), 0);

    try std.testing.expectEqualSlices(u8, str_1.items, str_2.items);
}
