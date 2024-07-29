const std = @import("std");
const Exprs = @import("../expr.zig");
const Tokens = @import("../tokens.zig");

const print = std.debug.print;
const ArrayList = std.ArrayList;
const obj = Tokens.obj;
const Token = Tokens.Token;
const Allocator = std.mem.Allocator;
const Expr = Exprs.Expr;

pub fn printTokens(tokens: ArrayList(Token)) void {
    for (tokens.items) |token| {
        print("line: {}, tType: {s}, lexeme.?: {s}", .{ token.line, @tagName(token.tType), token.lexeme.?.? });

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

pub const AstPrinter = struct {
    allocator: Allocator,

    pub fn init(allocator: Allocator) AstPrinter {
        return .{ .allocator = allocator };
    }

    pub fn print(self: *AstPrinter, expr: Expr) ![]u8 {
        return switch (expr) {
            .Binary => |b| self.parenthesize(b.operator.lexeme.?, &.{ b.left, b.right }),
            .Unary => |u| self.parenthesize(u.operator.lexeme.?, &.{u.right}),
            .Literal => |l| if (l.value) |v| std.fmt.allocPrint(self.allocator, "{any}", .{v}) else std.fmt.allocPrint(self.allocator, "null", .{}),
            .Grouping => |g| self.parenthesize("group", &.{g.expression}),
        };
    }

    fn parenthesize(self: *AstPrinter, name: []const u8, exprs: []const Expr) anyerror![]u8 {
        var list = std.ArrayList(u8).init(self.allocator);
        defer list.deinit();

        try list.writer().print("({s}", .{name});
        for (exprs) |expr| {
            try list.appendSlice(" ");
            const result = try self.print(expr);
            defer self.allocator.free(result);
            try list.appendSlice(result);
        }
        try list.appendSlice(")");

        return list.toOwnedSlice();
    }
};
