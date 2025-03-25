const std = @import("std");
const Allocator = std.mem.Allocator;
const panic = std.debug.panic;

const p = @import("parser.zig");
const AST = @import("AST.zig");

pub const Interpreter = struct {
    parser: p.Parser = undefined,
    alloc: Allocator,

    fn visit_bin_op(self: *Interpreter, node: AST.BinOp) f64 {
        const left_val: f64 = switch (node.left.*) {
            .number => |child| child.token.getNumber() catch |e| panic("{any}", .{e}),
            .bin_op => |child| self.visit_bin_op(child),
            else => unreachable,
        };
        const right_val: f64 = switch (node.right.*) {
            .number => |child| child.token.getNumber() catch |e| panic("{any}", .{e}),
            .bin_op => |child| self.visit_bin_op(child),
            else => unreachable,
        };

        return switch (node.token.variant()) {
            .add => left_val + right_val,
            .sub => left_val - right_val,
            .mul => left_val * right_val,
            .div => left_val / right_val,
            else => unreachable,
        };
    }

    pub fn interpret(self: *Interpreter, input: []const u8) f64 {
        self.parser = p.Parser{ .alloc = self.alloc };
        const ast_root = self.parser.parse(input);
        defer ast_root.destroy(self.alloc);
        return self.visit_bin_op(ast_root.bin_op);
    }
};

test "interpreter" {
    const alloc = std.testing.allocator;
    const input = "14 + 8 * (1 - 8 / 2) * (4 / (2 + 4))";
    const expected: f64 = -2;

    var interpreter = Interpreter{ .alloc = alloc };
    const result = interpreter.interpret(input);

    try std.testing.expectEqual(expected, result);
}
