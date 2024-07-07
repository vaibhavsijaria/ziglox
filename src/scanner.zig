const std = @import("std");
const print = std.debug.print;
const Allocator = std.mem.Allocator;
const fs = std.fs;
const ArrayList = std.ArrayList;

pub fn runFile(allocator: Allocator, path: []const u8) !void {
    const file = try fs.cwd().openFile(path, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const buffer = try allocator.alloc(u8, file_size);
    defer allocator.free(buffer);
    _ = try file.readAll(buffer);
}

pub fn runPrompt() !void {
    var buffer: [1024]u8 = undefined;
    const stdin = std.io.getStdIn();
    const reader = stdin.reader();

    while (true) {
        const prompt = try reader.readUntilDelimiter(&buffer, '\n');
        try run(prompt);
    }
}

pub fn run(source: []const u8) !void {
    print("{s}\n", .{source});
}
