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
const TokenType = Tokens.TokenType;
const ParseError = Errors.ParseError;
const print = std.debug.print;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub const Parser = struct {
    allocator: Allocator,
    tokens: ArrayList(Token),
    current: usize,

    pub fn init(allocator: Allocator, tokens: ArrayList(Token)) Parser {
        return .{
            .allocator = allocator,
            .tokens = tokens,
            .current = 0,
        };
    }

    pub fn parse(self: *Parser) !ArrayList(Stmt) {
        var statements = ArrayList(Stmt).init(self.allocator);
        while (!self.isAtEnd())
            try statements.append(try self.statement());

        // return self.expression() catch null;
        return statements;
    }

    fn statement(self: *Parser) !Stmt {
        if (self.match(&.{.PRINT})) return try self.print();

        return self.exprs();
    }

    fn print(self: *Parser) !Stmt {
        const expr = try self.expression();

        _ = self.consume(.SEMICOLON, "Expect ';' after value.") catch self.synchronize();
        return Stmt{ .Print = Stmts.Print{ .expr = expr } };
    }

    fn exprs(self: *Parser) !Stmt {
        const expr = try self.expression();
        _ = self.consume(.SEMICOLON, "Expect ';' after value.") catch self.synchronize();

        return Stmt{ .Expr = Stmts.ExprStmt{ .expr = expr } };
    }

    fn expression(self: *Parser) !*Expr {
        return try self.comma();
    }

    fn comma(self: *Parser) !*Expr {
        var expr = try self.conditional();

        while (self.match(&.{.COMMA})) {
            const operator = self.previous();
            const right = try self.conditional();
            const binary_expr = try self.allocator.create(Expr);
            binary_expr.* = Expr{ .Binary = Exprs.Binary{
                .left = expr,
                .operator = operator,
                .right = right,
            } };
            expr = binary_expr;
        }
        return expr;
    }

    fn conditional(self: *Parser) anyerror!*Expr {
        var expr = try self.equality();

        if (self.match(&.{.QUESTION_MARK})) {
            const then_branch = try self.expression();
            _ = try self.consume(.COLON, "Expect ':' after conditional expression.");
            const else_branch = try self.equality();
            const ternary_expr = try self.allocator.create(Expr);
            ternary_expr.* = Expr{ .Ternary = Exprs.Ternary{
                .condition = expr,
                .then_branch = then_branch,
                .else_branch = else_branch,
            } };
            expr = ternary_expr;
        }

        return expr;
    }

    fn equality(self: *Parser) !*Expr {
        var expr = try self.comparison();

        while (self.match(&.{ .BANG_EQUAL, .EQUAL_EQUAL })) {
            const operator = self.previous();
            const right = try self.comparison();
            const binary_expr = try self.allocator.create(Expr);
            binary_expr.* = Expr{ .Binary = Exprs.Binary{
                .left = expr,
                .operator = operator,
                .right = right,
            } };
            expr = binary_expr;
        }

        return expr;
    }

    fn comparison(self: *Parser) !*Expr {
        var expr = try self.term();

        while (self.match(&.{
            .GREATER,
            .GREATER_EQUAL,
            .LESS,
            .LESS_EQUAL,
        })) {
            const operator = self.previous();
            const right = try self.term();
            const binary_expr = try self.allocator.create(Expr);
            binary_expr.* = Expr{ .Binary = Exprs.Binary{
                .left = expr,
                .operator = operator,
                .right = right,
            } };
            expr = binary_expr;
        }

        return expr;
    }

    fn term(self: *Parser) !*Expr {
        var expr = try self.factor();

        while (self.match(&.{ .MINUS, .PLUS })) {
            const operator = self.previous();
            const right = try self.factor();
            const binary_expr = try self.allocator.create(Expr);
            binary_expr.* = Expr{ .Binary = Exprs.Binary{
                .left = expr,
                .operator = operator,
                .right = right,
            } };
            expr = binary_expr;
        }

        return expr;
    }

    fn factor(self: *Parser) !*Expr {
        var expr = try self.unary();

        while (self.match(&.{ .SLASH, .STAR })) {
            const operator = self.previous();
            const right = try self.unary();
            const binary_expr = try self.allocator.create(Expr);
            binary_expr.* = Expr{ .Binary = Exprs.Binary{
                .left = expr,
                .operator = operator,
                .right = right,
            } };
            expr = binary_expr;
        }

        return expr;
    }

    fn unary(self: *Parser) !*Expr {
        if (self.match(&.{ .BANG, .MINUS })) {
            const operator = self.previous();
            const right = try self.unary();
            const unary_expr = try self.allocator.create(Expr);
            unary_expr.* = Expr{ .Unary = .{ .operator = operator, .right = right } };
            return unary_expr;
        }

        return try self.primary();
    }

    fn primary(self: *Parser) anyerror!*Expr {
        const primary_expr = try self.allocator.create(Expr);

        if (self.matchLiteral()) |literal| {
            primary_expr.* = literal;
            return primary_expr;
        }

        if (self.match(&.{.LEFT_PAREN})) {
            return self.grouping(primary_expr);
        }

        Error.printerr(self.peek(), "Expect expression");
        return ParseError.ExpectExpr;
    }

    fn matchLiteral(self: *Parser) ?Expr {
        if (self.match(&.{.FALSE})) {
            return Expr{ .Literal = Exprs.Literal{ .value = obj{ .boolean = false } } };
        }

        if (self.match(&.{.TRUE})) {
            return Expr{ .Literal = Exprs.Literal{ .value = obj{ .boolean = true } } };
        }

        if (self.match(&.{.NIL})) {
            return Expr{ .Literal = Exprs.Literal{ .value = null } };
        }

        if (self.match(&.{ .NUMBER, .STRING })) {
            return Expr{ .Literal = Exprs.Literal{ .value = self.previous().literal } };
        }

        return null;
    }

    fn grouping(self: *Parser, primary_expr: *Expr) !*Expr {
        const expr = try self.expression();
        _ = self.consume(.RIGHT_PAREN, "Expect ')' after expression.") catch self.synchronize();
        primary_expr.* = Expr{ .Grouping = Exprs.Grouping{ .expression = expr } };
        return primary_expr;
    }

    fn match(self: *Parser, comptime tTypes: []const TokenType) bool {
        for (tTypes) |tType| {
            if (self.check(tType)) {
                _ = self.advance();
                return true;
            }
        }

        return false;
    }

    fn consume(self: *Parser, tType: TokenType, msg: []const u8) !Token {
        if (self.check(tType)) return self.advance();

        Error.printerr(self.peek(), msg);
        return switch (tType) {
            .LEFT_PAREN, .RIGHT_PAREN => ParseError.MissingParen,
            else => ParseError.GenericError,
        };
    }

    fn synchronize(self: *Parser) void {
        _ = self.advance();

        while (!self.isAtEnd()) {
            if (self.previous().tType == .SEMICOLON) return;

            switch (self.peek().tType) {
                .CLASS,
                .FUN,
                .VAR,
                .FOR,
                .IF,
                .WHILE,
                .PRINT,
                .RETURN,
                => return,
                else => {},
            }

            _ = self.advance();
        }
    }

    fn advance(self: *Parser) Token {
        if (!self.isAtEnd()) self.current += 1;
        return self.previous();
    }

    fn check(self: *Parser, tType: TokenType) bool {
        if (self.isAtEnd()) return false;
        return self.peek().tType == tType;
    }

    fn isAtEnd(self: *Parser) bool {
        return self.peek().tType == TokenType.EOF;
    }

    fn peek(self: *Parser) Token {
        return self.tokens.items[self.current];
    }

    fn previous(self: *Parser) Token {
        return self.tokens.items[self.current - 1];
    }
};
