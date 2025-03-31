const std = @import("std");
const print = std.debug.print;
const Interpreter = @import("interpreter.zig").Interpreter;

const Error = error{NoSourceSpecified};

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    const alloc = arena.allocator();

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    if (args.len < 2) return Error.NoSourceSpecified;

    const file_path = args[1];
    const cwd = std.fs.cwd();
    const file = try cwd.openFileZ(file_path, .{ .mode = .read_only });
    defer file.close();

    const buffer = try alloc.alloc(u8, 4096);
    defer alloc.free(buffer);
    const len = try file.read(buffer);
    const input = buffer[0..len];

    print("reading file: {s}\n", .{file_path});
    print("interpreting:\n{s}\n", .{input});
    var interpreter = Interpreter.init(&arena);
    const result = try interpreter.interpret(input);
    print("result = {?d}\n", .{result});
}
