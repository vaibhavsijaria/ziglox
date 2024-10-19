const std = @import("std");
const Tokens = @import("tokens.zig");
const Exprs = @import("expr.zig");
const Stmts = @import("stmt.zig");
const Errors = @import("error.zig");

const obj = Tokens.obj;
const Expr = Exprs.Expr;
const Stmt = Stmts.Stmt;
const Error = Errors.Error;
const Token = Tokens.Token;
const print = std.debug.print;
const TokenType = Tokens.TokenType;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const RuntimeErrors = Errors.RuntimeError;

pub const Interpreter = struct {
    allocator: Allocator,

    pub fn init(allocator: Allocator) Interpreter {
        return .{
            .allocator = allocator,
        };
    }

    pub fn interpret(self: *Interpreter, statements: ArrayList(Stmt)) void {
        for (statements.items) |stmt| {
            _ = switch (stmt) {
                .Expr => |expr| self.exprStmt(expr),
                .Print => |expr| self.printStmt(expr),
                else => continue,
            };
        }
    }

    fn exprStmt(self: *Interpreter, stmt: Stmts.ExprStmt) void {
        _ = self.evaluate(stmt.expr);
    }

    fn printStmt(self: *Interpreter, stmt: Stmts.Print) void {
        const val = self.evaluate(stmt.expr);
        printObj(val);
    }

    fn evaluate(self: *Interpreter, expr: *Expr) ?obj {
        return switch (expr.*) {
            .Binary => |b| self.binary(b) catch null,
            .Unary => |u| self.unary(u) catch null,
            .Literal => |l| self.literal(l) catch null,
            .Grouping => |g| self.grouping(g) catch null,
            else => null, // temp
            // .Ternary => |t| self.ternary(t),
        };
    }

    fn literal(self: *Interpreter, expr: Exprs.Literal) !?obj {
        _ = self;
        return expr.value;
    }

    fn grouping(self: *Interpreter, expr: Exprs.Grouping) anyerror!?obj {
        return self.evaluate(expr.expression);
    }

    fn unary(self: *Interpreter, expr: Exprs.Unary) anyerror!?obj {
        const right = self.evaluate(expr.right);

        return switch (expr.operator.tType) {
            .BANG => obj{ .boolean = !truthVal(right) },

            .MINUS => if (right) |v| switch (v) {
                .num => |n| obj{ .num = -n },

                else => invalid_opd: {
                    Error.printerr(expr.operator, "Invalid operator for the operand");
                    break :invalid_opd RuntimeErrors.InvalidOperation;
                },
            } else null,

            else => invalid_opt: {
                Error.printerr(expr.operator, "Cannot be used as unary operator");
                break :invalid_opt RuntimeErrors.InvalidOperation;
            },
        };
    }

    fn binary(self: *Interpreter, expr: Exprs.Binary) anyerror!?obj {
        const left = self.evaluate(expr.left) orelse {
            Error.printerr(expr.operator, "Error while interpreting left operand");
            return RuntimeErrors.NullType;
        };
        const right = self.evaluate(expr.right) orelse {
            Error.printerr(expr.operator, "Error while interpreting right operand");
            return RuntimeErrors.NullType;
        };

        if (@intFromEnum(left) != @intFromEnum(right)) {
            Error.printerr(expr.operator, "Cannot perform binary operation on different types");
            return RuntimeErrors.IncompatibleTypes;
        }

        return switch (left) {
            .str => |l| switch (expr.operator.tType) {
                .PLUS => obj{ .str = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ l, right.str }) },
                else => invalid_opd: {
                    Error.printerr(expr.operator, "Invalid operation on string type");
                    break :invalid_opd RuntimeErrors.InvalidOperation;
                },
            },
            .num => |l| switch (expr.operator.tType) {
                .PLUS => obj{ .num = l + right.num },
                .MINUS => obj{ .num = l - right.num },
                .STAR => obj{ .num = l * right.num },
                .SLASH => slash: {
                    if (right.num == 0) {
                        Error.printerr(expr.operator, "Division by zero");
                        break :slash RuntimeErrors.DivisionByZero;
                    }
                    break :slash obj{ .num = l / right.num };
                },
                .GREATER => obj{ .boolean = l > right.num },
                .GREATER_EQUAL => obj{ .boolean = l >= right.num },
                .LESS => obj{ .boolean = l < right.num },
                .LESS_EQUAL => obj{ .boolean = l <= right.num },
                .EQUAL_EQUAL => obj{ .boolean = isEqual(left, right) },
                .BANG_EQUAL => obj{ .boolean = !isEqual(left, right) },
                else => null,
            },
            else => invalid_opd: {
                Error.printerr(expr.operator, "Invalid operation on numeric type");
                break :invalid_opd RuntimeErrors.InvalidOperation;
            }, // temp
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

    fn printObj(value: ?obj) void {
        if (value) |v| {
            switch (v) {
                .str => |s| print("{s}", .{s}),
                .num => |n| print("{d}", .{n}),
                .boolean => |b| print("{}", .{b}),
            }
        } else print("nil", .{});

        print("\n", .{});
    }
};
