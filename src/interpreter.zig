const std = @import("std");
const Allocator = std.mem.Allocator;
const panic = std.debug.panic;

const p = @import("parser.zig");
const AST = @import("AST.zig");

const Error = error{
    UnexpectedNode,
    NotAVariable,
    UnexpectedStatement,
    VariableDoesNotExist,
    UnexpectedToken,
};

pub const Interpreter = struct {
    parser: p.Parser = undefined,
    alloc: Allocator,
    global_vars: std.StringHashMap(f64) = undefined,

    fn visit_compound(self: *Interpreter, node: *const AST.Node) !void {
        switch (node.*) {
            .compound => |compound| {
                for (compound.children) |*child| {
                    try self.visit_statement(child);
                }
            },
            else => return Error.UnexpectedNode,
        }
    }

    fn visit_statement(self: *Interpreter, node: *const AST.Node) !void {
        switch (node.*) {
            .assign_op => |assign_op| {
                const var_id: []u8 = try self.var_id_from_node(assign_op.left);
                const rhsv = try self.val_from_node(assign_op.right);
                try self.global_vars.put(var_id, rhsv);
            },
            else => return Error.UnexpectedStatement,
        }
    }

    fn var_id_from_node(self: *Interpreter, node: *const AST.Node) ![]u8 {
        _ = self;
        return switch (node.*) {
            .variable => |v| try v.token.getIdentifier(),
            else => Error.NotAVariable,
        };
    }

    fn val_from_node(self: *Interpreter, node: *const AST.Node) anyerror!f64 {
        return switch (node.*) {
            .number => |*n| try n.token.getNumber(),
            .bin_op => |*op| self.visit_bin_op(op),
            .unary_op => |*op| self.visit_unary_op(op),
            .variable => |*v| blk: {
                const var_id = try v.token.getIdentifier();
                const value = self.global_vars.get(var_id) orelse {
                    return Error.VariableDoesNotExist;
                };
                break :blk value;
            },
            else => Error.UnexpectedNode,
        };
    }

    fn visit_bin_op(self: *Interpreter, node: *const AST.BinOp) !f64 {
        const left_val: f64 = try self.val_from_node(node.left);
        const right_val: f64 = try self.val_from_node(node.right);

        return switch (node.token.variant()) {
            .add => left_val + right_val,
            .sub => left_val - right_val,
            .mul => left_val * right_val,
            .div => left_val / right_val,
            else => Error.UnexpectedToken,
        };
    }

    fn visit_unary_op(self: *Interpreter, node: *const AST.UnaryOp) !f64 {
        const operand_val: f64 = try self.val_from_node(node.operand);
        return switch (node.token.variant()) {
            .add => operand_val,
            .sub => -operand_val,
            else => Error.UnexpectedToken,
        };
    }

    pub fn interpret(self: *Interpreter, input: []const u8) !?f64 {
        self.parser = p.Parser{ .alloc = self.alloc };

        self.global_vars = std.StringHashMap(f64).init(self.alloc);
        defer self.global_vars.deinit();

        const ast_root = try self.parser.parse(input);
        defer ast_root.destroy(self.alloc);

        try self.visit_compound(&ast_root);
        const result = self.global_vars.get("result");
        return result;
    }
};

test "interpret bin_op only" {
    const alloc = std.testing.allocator;
    const input = "{result = 14 + 8 * (1 - 8 / 2) * (4 / (2 + 4))}";
    const expected: f64 = -2;

    var interpreter = Interpreter{ .alloc = alloc };
    const result = interpreter.interpret(input);

    try std.testing.expectEqual(expected, result);
}

test "interpret with unary_op" {
    const alloc = std.testing.allocator;
    const input = "{result = 44 + -8 * -(2 / 8 + 0.5 * - (4))}";
    const expected: f64 = 30;

    var interpreter = Interpreter{ .alloc = alloc };
    const result = interpreter.interpret(input);

    try std.testing.expectEqual(expected, result);
}

test "interpret program v1" {
    const alloc = std.testing.allocator;
    const input =
        \\{
        \\  x = 12 / 8;
        \\  y = x - 4;
        \\  z = (x + y) * 12;
        \\  result = z - 8
        \\}
    ;
    const expected: f64 = -20;

    var interpreter = Interpreter{ .alloc = alloc };
    const result = interpreter.interpret(input);

    try std.testing.expectEqual(expected, result);
}
