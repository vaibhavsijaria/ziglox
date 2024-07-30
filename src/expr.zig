const std = @import("std");
const Tokens = @import("tokens.zig");

const Token = Tokens.Token;
const obj = Tokens.obj;

pub const Expr = union(enum) {
    Binary: *Binary,
    Grouping: *Grouping,
    Literal: *Literal,
    Unary: *Unary,
    Ternary: *Ternary,
    pub fn accept(self: Expr, visitor: anytype) @TypeOf(visitor.rtype) {
        return switch (self) {
            .Binary => |b| visitor.visitBinaryExpr(b),
            .Grouping => |g| visitor.visitGroupingExpr(g),
            .Literal => |l| visitor.visitLiteralExpr(l),
            .Unary => |u| visitor.visitUnaryExpr(u),
            .Ternary => |t| visitor.visitTernaryExpr(t),
        };
    }
};

pub const Binary = struct {
    left: Expr,
    operator: Token,
    right: Expr,
};

pub const Grouping = struct {
    expression: Expr,
};

pub const Literal = struct {
    value: ?obj,
};

pub const Unary = struct {
    operator: Token,
    right: Expr,
};

pub const Ternary = struct {
    condition: Expr,
    then_branch: Expr,
    else_branch: Expr,
};
