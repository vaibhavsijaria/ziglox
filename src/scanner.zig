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
    _ = try run(buffer);
}

pub fn runPrompt() !void {
    var input: [1024]u8 = undefined;
    const stdin = std.io.getStdIn();
    const reader = stdin.reader();
    var buffer = std.io.fixedBufferStream(&input);
    const writer = buffer.writer();

    while (true) {
        print(">>> ", .{});
        input = undefined;
        if (reader.streamUntilDelimiter(writer, '\n', buffer.buffer.len)) {
            _ = try writer.write("\n");
            _ = try run(buffer.buffer);
        } else |_| {
            print("Existing...", .{});
            break;
        }
        buffer.reset();
    }
}

pub fn run(source: []const u8) !void {
    print("{s}", .{source});
}
