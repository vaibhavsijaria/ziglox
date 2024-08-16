const std = @import("std");
const Tokens = @import("tokens.zig");

const Token = Tokens.Token;
const obj = Tokens.obj;

pub const Expr = union(enum) {
    Binary: Binary,
    Grouping: Grouping,
    Literal: Literal,
    Unary: Unary,
    Ternary: Ternary,
};

pub const Binary = struct {
    left: *Expr,
    operator: Token,
    right: *Expr,
};

pub const Grouping = struct {
    expression: *Expr,
};

pub const Literal = struct {
    value: ?obj,
};

pub const Unary = struct {
    operator: Token,
    right: *Expr,
};

pub const Ternary = struct {
    condition: *Expr,
    then_branch: *Expr,
    else_branch: *Expr,
};
