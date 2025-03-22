const std = @import("std");

const Lexer = @import("lexer.zig").Lexer;
const Rc = @import("ref_counter.zig").Rc;
const RcNode = Rc(AST.Node);

const AST = @import("AST.zig");
const t = @import("token.zig");

const Parser = struct {
    lexer: Lexer,
};

test "simple test" {
    const alloc = std.testing.allocator;
    const test_input = "2 * 7 + 3";
    _ = test_input;

    const two_token = try t.Token.createNumber(alloc, 2);
    defer two_token.destroy(alloc);

    const seven_token = try t.Token.createNumber(alloc, 7);
    defer seven_token.destroy(alloc);

    const three_token = try t.Token.createNumber(alloc, 3);
    defer three_token.destroy(alloc);

    const mul_token = t.Token.createBasic(t.Variants.mul);
    const add_token = t.Token.createBasic(t.Variants.add);

    const two_node = AST.Node{ .number = .{ .token = two_token } };
    const seven_node = AST.Node{ .number = .{ .token = seven_token } };

    const mul_node = AST.Node{ .bin_op = .{
        .token = mul_token,
        .left = RcNode.init(alloc, two_node),
        .right = RcNode.init(alloc, seven_node),
    } };

    const three_node = AST.Node{ .number = .{ .token = three_token } };
    const add_node = AST.Node{ .bin_op = .{
        .token = add_token,
        .left = RcNode.manage(alloc, &mul_node),
        .right = RcNode.manage(alloc, &three_node),
    } };

    _ = add_node;
}
