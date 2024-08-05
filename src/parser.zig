const std = @import("std");
const Tokens = @import("tokens.zig");
const Exprs = @import("expr.zig");
const Errors = @import("error.zig");

const obj = Tokens.obj;
const Expr = Exprs.Expr;
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

    pub fn parse(self: *Parser) ?Expr {
        return self.expression() catch null;
    }

    fn expression(self: *Parser) !Expr {
        return try self.comma();
    }

    fn comma(self: *Parser) !Expr {
        var expr = try self.conditional();

        while (self.match(&.{.COMMA})) {
            const operator = self.previous();
            const right = try self.conditional();
            const binary = try self.allocator.create(Exprs.Binary);
            binary.* = Exprs.Binary{
                .left = expr,
                .operator = operator,
                .right = right,
            };
            expr = Expr{ .Binary = binary };
        }
        return expr;
    }

    fn conditional(self: *Parser) anyerror!Expr {
        var expr = try self.equality();

        if (self.match(&.{.QUESTION_MARK})) {
            const then_branch = try self.expression();
            _ = try self.consume(.COLON, "Expect ':' after conditional expression.");
            const else_branch = try self.equality();

            const ternary = try self.allocator.create(Exprs.Ternary);
            ternary.* = Exprs.Ternary{
                .condition = expr,
                .then_branch = then_branch,
                .else_branch = else_branch,
            };
            expr = Expr{ .Ternary = ternary };
        }

        return expr;
    }

    fn equality(self: *Parser) !Expr {
        var expr = try self.comparison();

        while (self.match(&.{ .BANG_EQUAL, .EQUAL_EQUAL })) {
            const operator = self.previous();
            const right = try self.comparison();
            const binary = try self.allocator.create(Exprs.Binary);
            binary.* = Exprs.Binary{
                .left = expr,
                .operator = operator,
                .right = right,
            };
            expr = Expr{ .Binary = binary };
        }

        return expr;
    }

    fn comparison(self: *Parser) !Expr {
        var expr = try self.term();

        while (self.match(&.{
            .GREATER,
            .GREATER_EQUAL,
            .LESS,
            .LESS_EQUAL,
        })) {
            const operator = self.previous();
            const right = try self.term();
            const binary = try self.allocator.create(Exprs.Binary);
            binary.* = Exprs.Binary{
                .left = expr,
                .operator = operator,
                .right = right,
            };
            expr = Expr{ .Binary = binary };
        }

        return expr;
    }

    fn term(self: *Parser) !Expr {
        var expr = try self.factor();

        while (self.match(&.{ .MINUS, .PLUS })) {
            const operator = self.previous();
            const right = try self.factor();
            const binary = try self.allocator.create(Exprs.Binary);
            binary.* = Exprs.Binary{
                .left = expr,
                .operator = operator,
                .right = right,
            };
            expr = Expr{ .Binary = binary };
        }

        return expr;
    }

    fn factor(self: *Parser) !Expr {
        var expr = try self.unary();

        while (self.match(&.{ .SLASH, .STAR })) {
            const operator = self.previous();
            const right = try self.unary();
            const binary = try self.allocator.create(Exprs.Binary);
            binary.* = Exprs.Binary{
                .left = expr,
                .operator = operator,
                .right = right,
            };
            expr = Expr{ .Binary = binary };
        }

        return expr;
    }

    fn unary(self: *Parser) !Expr {
        if (self.match(&.{ .BANG, .MINUS })) {
            const operator = self.previous();
            const right = try self.unary();
            const unary_expr = try self.allocator.create(Exprs.Unary);
            unary_expr.* = .{ .operator = operator, .right = right };
            return Expr{ .Unary = unary_expr };
        }

        return try self.primary();
    }

    fn primary(self: *Parser) anyerror!Expr {
        if (self.match(&.{.FALSE})) {
            const literal = try self.allocator.create(Exprs.Literal);
            literal.* = Exprs.Literal{ .value = obj{ .boolean = false } };
            return Expr{ .Literal = literal };
        }

        if (self.match(&.{.TRUE})) {
            const literal = try self.allocator.create(Exprs.Literal);
            literal.* = Exprs.Literal{ .value = obj{ .boolean = true } };
            return Expr{ .Literal = literal };
        }

        if (self.match(&.{.NIL})) {
            const literal = try self.allocator.create(Exprs.Literal);
            literal.* = Exprs.Literal{ .value = null };
            return Expr{ .Literal = literal };
        }

        if (self.match(&.{ .NUMBER, .STRING })) {
            const literal = try self.allocator.create(Exprs.Literal);
            literal.* = Exprs.Literal{ .value = self.previous().literal };
            return Expr{ .Literal = literal };
        }

        if (self.match(&.{.LEFT_PAREN})) {
            const expr = try self.expression();
            _ = self.consume(.RIGHT_PAREN, "Expect ')' after expression.") catch self.synchronize();
            const grouping = try self.allocator.create(Exprs.Grouping);
            grouping.* = Exprs.Grouping{ .expression = expr };
            return Expr{ .Grouping = grouping };
        }

        Error.printerr(self.peek(), "Expect expression");
        return ParseError.ExpectExpr;
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
