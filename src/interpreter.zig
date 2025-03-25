const std = @import("std");
const Allocator = std.mem.Allocator;
const panic = std.debug.panic;

const p = @import("parser.zig");
const AST = @import("AST.zig");

pub const Interpreter = struct {
    parser: p.Parser = undefined,
    alloc: Allocator,

    fn val_from_node(node: *const AST.Node) f64 {
        return switch (node.*) {
            .number => |n| n.token.getNumber() catch |e| panic("{any}", .{e}),
            .bin_op => |op| Interpreter.visit_bin_op(&op),
            .unary_op => |op| Interpreter.visit_unary_op(&op),
            else => unreachable,
        };
    }

    fn visit_bin_op(node: *const AST.BinOp) f64 {
        const left_val: f64 = Interpreter.val_from_node(node.left);
        const right_val: f64 = Interpreter.val_from_node(node.right);

        return switch (node.token.variant()) {
            .add => left_val + right_val,
            .sub => left_val - right_val,
            .mul => left_val * right_val,
            .div => left_val / right_val,
            else => unreachable,
        };
    }

    fn visit_unary_op(node: *const AST.UnaryOp) f64 {
        const operand_val: f64 = Interpreter.val_from_node(node.operand);
        return switch (node.token.variant()) {
            .add => operand_val,
            .sub => -operand_val,
            else => unreachable,
        };
    }

    pub fn interpret(self: *Interpreter, input: []const u8) f64 {
        self.parser = p.Parser{ .alloc = self.alloc };
        const ast_root = self.parser.parse(input);
        defer ast_root.destroy(self.alloc);

        return Interpreter.val_from_node(&ast_root);
    }
};

test "interpret bin_op only" {
    const alloc = std.testing.allocator;
    const input = "14 + 8 * (1 - 8 / 2) * (4 / (2 + 4))";
    const expected: f64 = -2;

    var interpreter = Interpreter{ .alloc = alloc };
    const result = interpreter.interpret(input);

    try std.testing.expectEqual(expected, result);
}

test "interpret with unary_op" {
    const alloc = std.testing.allocator;
    const input = "44 + -8 * -(2 / 8 + 0.5 * - (4))";
    const expected: f64 = 30;

    var interpreter = Interpreter{ .alloc = alloc };
    const result = interpreter.interpret(input);

    try std.testing.expectEqual(expected, result);
}
