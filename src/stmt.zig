const std = @import("std");
const Expr = @import("expr.zig").Expr;
const Tokens = @import("tokens.zig");

const Token = Tokens.Token;
const ArrayList = std.ArrayList;

pub const Stmt = union(enum) {
    Expr: ExprStmt,
    Func: Func,
    Print: Print,
    VarStmt: VarStmt,
};

pub const Func = struct {
    name: Token,
    params: ArrayList(Token),
    body: ArrayList(Stmt),
};

pub const ExprStmt = struct {
    expr: *Expr,
};

pub const Print = struct {
    expr: *Expr,
};

pub const VarStmt = struct {
    name: Token,
    initializer: ?*Expr,
};
