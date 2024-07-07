const std = @import("std");
const print = std.debug.print;

const scanner = @import("scanner.zig");
const runFile = scanner.runFile;
const runPrompt = scanner.runPrompt;

pub fn main() !void {
    var args = std.process.args();
    _ = args.next().?;
    if (args.next()) |path| {
        if (args.skip()) {
            print("Usage: ziglox [script]\n", .{});
        } else {
            var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
            defer arena.deinit();

            const allocator = arena.allocator();

            try runFile(allocator, path);
        }
    } else {
        try runPrompt();
    }
    return;
}
