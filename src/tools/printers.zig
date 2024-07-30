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

    pub fn init(allocator: Allocator) AstPrinter {
        return .{ .allocator = allocator };
    }

    pub fn print(self: *AstPrinter, expr: Expr) void {
        switch (expr) {
            .Binary => |b| self.parenthesize(b.operator.lexeme.?, &.{ b.left, b.right }),
            .Unary => |u| self.parenthesize(u.operator.lexeme.?, &.{u.right}),
            .Literal => |l| if (l.value) |v| printLiteral(v) else std.debug.print("null", .{}),
            .Grouping => |g| self.parenthesize("group", &.{g.expression}),
            .Ternary => |t| self.printTernary(t),
        }
    }

    fn parenthesize(self: *AstPrinter, name: []const u8, exprs: []const Expr) void {
        std.debug.print("({s}", .{name});

        for (exprs) |expr| {
            std.debug.print(" ", .{});
            self.print(expr);
        }
        std.debug.print(")", .{});
    }

    fn printLiteral(literal: obj) void {
        switch (literal) {
            .str => |s| std.debug.print("\"{s}\"", .{s}),
            .num => |n| std.debug.print("{d}", .{n}),
            .boolean => |b| std.debug.print("{}", .{b}),
        }
    }

    fn printTernary(self: *AstPrinter, ternary: *Exprs.Ternary) void {
        std.debug.print("(? ", .{});
        self.print(ternary.condition);
        std.debug.print(" ", .{});
        self.print(ternary.then_branch);
        std.debug.print(" ", .{});
        self.print(ternary.else_branch);
        std.debug.print(")", .{});
    }
};
