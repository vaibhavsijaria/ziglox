const std = @import("std");

const print = std.debug.print;
const ArrayList = std.ArrayList;
const Tokens = @import("../tokens.zig");
const Token = Tokens.Token;

pub fn printTokens(tokens: ArrayList(Token)) void {
    for (tokens.items) |token| {
        print("line: {}, tType: {s}, lexeme: {s}", .{ token.line, @tagName(token.tType), token.lexeme.? });

        if (token.literal) |literal| {
            switch (literal) {
                .str => |s| print(", literal: \"{s}\"", .{s}),
                .num => |n| print(", literal: {d}", .{n}),
                .boolean => |b| print(", boolean: {}", .{b}),
            }
        }

        print("\n", .{});
    }
}
