const std = @import("std");
const print = std.debug.print;

const run = @import("run.zig");
const runFile = run.runFile;
const runPrompt = run.runPrompt;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.next().?;

    if (args.next()) |path| {
        if (args.skip()) {
            print("Usage: ziglox [script]\n", .{});
        } else {
            try runFile(allocator, path);
        }
    } else {
        try runPrompt(allocator);
    }
    return;
}
