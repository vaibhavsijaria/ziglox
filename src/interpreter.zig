const std = @import("std");
const Tokens = @import("tokens.zig");
const Exprs = @import("expr.zig");
const Errors = @import("error.zig");

const obj = Tokens.obj;
const Expr = Exprs.Expr;
const Token = Tokens.Token;
const TokenType = Tokens.TokenType;

pub const Interpreter = struct {
    fn interpret(self: *Interpreter, expr: *Expr) ?obj {
        return switch (expr.*) {
            .Binary => |b| self.binary(b),
            .Unary => |u| self.unary(u),
            .Literal => |l| self.literal(l),
            .Grouping => |g| self.grouping(g),
            .Ternary => |t| self.ternary(t),
        };
    }

    fn literal(self: *Interpreter, expr: Exprs.Literal) ?obj {
        _ = self;
        return expr.value;
    }

    fn grouping(self: *Interpreter, expr: Exprs.Grouping) ?obj {
        return self.interpret(expr.expression);
    }

    fn unary(self: *Interpreter, expr: Exprs.Unary) ?obj {
        const right = self.interpret(expr.right);

        return switch (expr.operator.tType) {
            .MINUS => {
                if (right) |v| switch (v) {
                    .num => |n| obj{ .num = -n },
                    else => null,
                } else null;
            },
            .BANG => {},
        };
    }
};
