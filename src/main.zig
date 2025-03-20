const std = @import("std");
const print = std.debug.print;

pub fn main() !void {
    const argsArr = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, argsArr);

    const argsStr = try std.mem.join(alloc, " ", argsArr[1..]);

    var interpreter = Interpreter{ .input = argsStr };

    const result = interpreter.eval();

    print("{s}={d}\n", .{ argsStr, result });
}
