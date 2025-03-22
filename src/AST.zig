const std = @import("std");

const t = @import("token.zig");
const Rc = @import("ref_counter.zig").Rc;

pub const Num = struct {
    token: t.Token,
};

pub const Id = struct {
    token: t.Token,
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
    identifier: Id,
    bin_op: BinOp,
    unary_op: UnaryOp,

    pub fn createNumber(token: *const t.Token) !Node {
        if (std.meta.activeTag(token.*) != t.Variants.number) return Error.BadTokenForNodeType;
        return Node{ .number = Num{ .token = token.clone() } };
    }

    pub fn createIdentifier(token: *const t.Token) !Node {
        if (std.meta.activeTag(token.*) != t.Variants.identifier) return Error.BadTokenForNodeType;
        return Node{ .identifier = Id{ .token = token.clone() } };
    }

    pub fn createBinOp(alloc: std.mem.Allocator, token: *const t.Token, left: *const Node, right: *const Node) !Node {
        switch (std.meta.activeTag(token.*)) {
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

    pub fn createUnaryOp(alloc: std.mem.Allocator, token: *const t.Token, operand: *const Node) !Node {
        switch (std.meta.activeTag(token.*)) {
            t.Variants.add, t.Variants.sub => {},
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

    pub fn clone(self: *const Node, alloc: std.mem.Allocator) !Node {
        switch (self.*) {
            .number => |item| {
                return Node{ .number = .{ .token = item.token.clone() } };
            },
            .identifier => |item| {
                return Node{ .identifier = .{ .token = item.token.clone() } };
            },
            .bin_op => |item| {
                const left_ptr = try alloc.create(Node);
                errdefer alloc.destroy(left_ptr);
                left_ptr.* = try item.left.clone(alloc);

                const right_ptr = try alloc.create(Node);
                errdefer alloc.destroy(right_ptr);
                right_ptr.* = try item.left.clone(alloc);

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
        }
    }

    pub fn destroy(self: *const Node, alloc: std.mem.Allocator) void {
        switch (self.*) {
            .bin_op => |item| {
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
            .identifier => |item| item.token.destroy(alloc),
        }
    }
};

const Error = error{
    BadTokenForNodeType,
};

test "AST number nodes" {
    const alloc = std.testing.allocator;

    const number_token = try t.Token.createNumber(alloc, 12);
    defer number_token.destroy(alloc);

    const number_node = try Node.createNumber(&number_token);
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

    const identifier_node = try Node.createIdentifier(&identifier_token);
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

    const seven_node = try Node.createNumber(&seven_token);
    defer seven_node.destroy(alloc);

    const three_node = try Node.createNumber(&three_token);
    defer three_node.destroy(alloc);

    const seven_add_three_node = try Node.createBinOp(alloc, &add_token, &seven_node, &three_node);
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

    const five_node = try Node.createNumber(&five_token);
    defer five_node.destroy(alloc);

    const unnary_add_node = try Node.createUnaryOp(alloc, &add_token, &five_node);
    defer unnary_add_node.destroy(alloc);

    const clone_1 = try unnary_add_node.clone(alloc);
    defer clone_1.destroy(alloc);

    const clone_2 = try unnary_add_node.clone(alloc);
    defer clone_2.destroy(alloc);
}
