const std = @import("std");
const Printer = @import("tools/printers.zig");
const Scanner = @import("scanner.zig").Scanner;
const Parser = @import("parser.zig").Parser;
const printTokens = Printer.printTokens;
const AstPrinter = Printer.AstPrinter;
const Allocator = std.mem.Allocator;
const fs = std.fs;
const print = std.debug.print;

pub fn runFile(allocator: Allocator, path: []const u8) !void {
    const file = try fs.cwd().openFile(path, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const buffer = try allocator.alloc(u8, file_size);
    defer allocator.free(buffer);
    _ = try file.readAll(buffer);
    _ = try run(allocator, buffer);
}

pub fn runPrompt(allocator: Allocator) !void {
    var input: [1024]u8 = undefined;
    const stdin = std.io.getStdIn();
    const reader = stdin.reader();
    var buffer = std.io.fixedBufferStream(&input);
    const writer = buffer.writer();

    while (true) {
        print(">>> ", .{});
        input = undefined;
        if (reader.streamUntilDelimiter(
            writer,
            '\n',
            buffer.buffer.len,
        )) {
            _ = try writer.write("\n");
            const n = try buffer.getPos();
            const prompt = try allocator.dupe(u8, buffer.buffer[0..n]);
            _ = try run(allocator, prompt);
        } else |_| {
            print("Exiting...", .{});
            break;
        }
        buffer.reset();
    }
}

pub fn run(allocator: Allocator, source: []const u8) !void {
    var scanner = try Scanner.init(allocator, source);
    defer scanner.deinit();

    const tokens = try scanner.scanTokens();
    // printTokens(tokens);
    var parser = Parser.init(allocator, tokens);
    var expr = parser.parse().?;
    var printer = AstPrinter.init(allocator);
    print("{}", .{try printer.print(&expr)});
}
