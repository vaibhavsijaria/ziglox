const std = @import("std");
const Tokens = @import("tokens.zig");
const Exprs = @import("expr.zig");
const Errors = @import("error.zig");

const obj = Tokens.obj;
const Expr = Exprs.Expr;
const Token = Tokens.Token;
const TokenType = Tokens.TokenType;
const Allocator = std.mem.Allocator;

pub const Interpreter = struct {
    allocator: Allocator,

    pub fn init(allocator: Allocator) Interpreter {
        return .{
            .allocator = allocator,
        };
    }

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
            .BANG => obj{ .boolean = !truthVal(right) },
        };
    }

    fn binary(self: *Interpreter, expr: Exprs.Binary) ?obj {
        const left = self.interpret(expr.left);
        const right = self.interpret(expr.right);

        if (@intFromEnum(left) != @intFromEnum(right)) {
            // some error
        }

        return switch (expr.operator.tType) {
            .MINUS => {
                switch (left) {
                    .num => |l| {
                        const r = right.num;
                        obj{ .num = l - r };
                    },
                    else => {
                        // some error
                    },
                }
            },
            .PLUS => {
                switch (left) {
                    .num => |l| {
                        const r = right.num;
                        obj{ .num = l + r };
                    },
                    .str => |l| {
                        const r = right.str;
                        std.fmt.allocPrint(self.allocator, "{s}{s}", .{ l, r });
                    },
                }
            },
        };
    }

    fn truthVal(value: ?obj) bool {
        return if (value) |v| switch (v) {
            .boolean => |b| b,
            else => true,
        } else false;
    }
};
