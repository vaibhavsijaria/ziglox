const std = @import("std");
const Tokens = @import("tokens.zig");

const Token = Tokens.Token;
const obj = Tokens.obj;

pub const Expr = union(enum) {
    Binary: *Binary,
    Grouping: *Grouping,
    Literal: *Literal,
    Unary: *Unary,

    pub fn accept(self: Expr, visitor: anytype) @TypeOf(visitor.rtype) {
        return switch (self) {
            .Binary => |b| visitor.visitBinaryExpr(b),
            .Grouping => |g| visitor.visitGroupingExpr(g),
            .Literal => |l| visitor.visitLiteralExpr(l),
            .Unary => |u| visitor.visitUnaryExpr(u),
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
