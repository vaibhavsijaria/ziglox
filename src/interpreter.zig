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

    pub fn interpret(self: *Interpreter, expr: *Expr) !?obj {
        return switch (expr.*) {
            .Binary => |b| self.binary(b),
            .Unary => |u| self.unary(u),
            .Literal => |l| self.literal(l),
            .Grouping => |g| self.grouping(g),
            else => null, // temp
            // .Ternary => |t| self.ternary(t),
        };
    }

    fn literal(self: *Interpreter, expr: Exprs.Literal) !?obj {
        _ = self;
        return expr.value;
    }

    fn grouping(self: *Interpreter, expr: Exprs.Grouping) !?obj {
        return self.interpret(expr.expression);
    }

    fn unary(self: *Interpreter, expr: Exprs.Unary) !?obj {
        const right = try self.interpret(expr.right);

        return switch (expr.operator.tType) {
            .MINUS => if (right) |v| switch (v) {
                .num => |n| obj{ .num = -n },
                else => null, // some error
            } else null // some error
            ,
            .BANG => obj{ .boolean = !truthVal(right) },
            else => null, // some error
        };
    }

    fn binary(self: *Interpreter, expr: Exprs.Binary) anyerror!?obj {
        const left = try self.interpret(expr.left) orelse return null; // some error
        const right = try self.interpret(expr.right) orelse return null; // some error

        if (@intFromEnum(left) != @intFromEnum(right)) {
            // some error
        }

        return switch (left) {
            .str => |l| switch (expr.operator.tType) {
                .PLUS => obj{ .str = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ l, right.str }) },
                else => null, // some error
            },
            .num => |l| switch (expr.operator.tType) {
                .PLUS => obj{ .num = l + right.num },
                .MINUS => obj{ .num = l - right.num },
                .STAR => obj{ .num = l * right.num },
                .SLASH => obj{ .num = l / right.num },
                .GREATER => obj{ .boolean = l > right.num },
                .GREATER_EQUAL => obj{ .boolean = l >= right.num },
                .LESS => obj{ .boolean = l < right.num },
                .LESS_EQUAL => obj{ .boolean = l <= right.num },
                .EQUAL_EQUAL => obj{ .boolean = isEqual(left, right) },
                .BANG_EQUAL => obj{ .boolean = !isEqual(left, right) },
                else => null, // some error

            },
            else => null, // temp
        };
    }

    fn isEqual(val1: obj, val2: obj) bool {
        return switch (val1) {
            .num => |v1| v1 == val2.num,
            .str => |v1| std.mem.eql(u8, v1, val2.str),
            .boolean => |v1| v1 == val2.boolean,
        };
    }

    fn truthVal(value: ?obj) bool {
        return if (value) |v| switch (v) {
            .boolean => |b| b,
            else => true,
        } else false;
    }
};
