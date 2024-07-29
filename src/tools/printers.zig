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

pub const AstPrinter = struct {
    allocator: Allocator,
    rtype: anyerror![]u8,

    pub fn init(allocator: Allocator) AstPrinter {
        return .{ .allocator = allocator, .rtype = "" };
    }

    pub fn print(self: *AstPrinter, expr: Expr) ![]u8 {
        return expr.accept(self);
    }

    pub fn visitBinaryExpr(self: *AstPrinter, expr: *Exprs.Binary) ![]u8 {
        return try self.parenthesize(expr.operator.lexeme.?, &.{ expr.left, expr.right });
    }

    pub fn visitGroupingExpr(self: *AstPrinter, expr: *Exprs.Grouping) ![]u8 {
        return try self.parenthesize("group", &.{expr.expression});
    }

    pub fn visitLiteralExpr(self: *AstPrinter, expr: *Exprs.Literal) ![]u8 {
        if (expr.value) |value| {
            return switch (value) {
                .num => |n| try std.fmt.allocPrint(self.allocator, "{d}", .{n}),
                .str => |s| try std.fmt.allocPrint(self.allocator, "\"{s}\"", .{s}),
                .boolean => |b| if (b) try std.fmt.allocPrint(self.allocator, "true", .{}) else try std.fmt.allocPrint(self.allocator, "false", .{}),
            };
        }
        return try std.fmt.allocPrint(self.allocator, "nil", .{});
    }

    pub fn visitUnaryExpr(self: *AstPrinter, expr: *Exprs.Unary) ![]u8 {
        return try self.parenthesize(expr.operator.lexeme.?, &.{expr.right});
    }

    fn parenthesize(self: *AstPrinter, name: []const u8, exprs: []const Expr) ![]u8 {
        var list = ArrayList(u8).init(self.allocator);
        defer list.deinit();

        try list.appendSlice("(");
        try list.appendSlice(name);

        for (exprs) |expr| {
            try list.appendSlice(" ");
            const result = try expr.accept(self);
            defer self.allocator.free(result);
            try list.appendSlice(result);
        }

        try list.appendSlice(")");

        return list.toOwnedSlice();
    }
};
