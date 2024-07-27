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

    fn expression(self: *Parser) !*Expr {
        return try self.equality();
    }

    fn equality(self: *Parser) !*Expr {
        var expr = try self.comparison();

        while (self.match(&.{ .BANG_EQUAL, .EQUAL_EQUAL })) {
            const operator = self.previous();
            const right = try self.comparison();
            const left = expr;
            expr = try self.allocator.create(Exprs.Binary);
            expr.* = Exprs.Binary{
                .left = left,
                .operator = operator,
                .right = right,
            };
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
            const left = expr;
            expr = try self.allocator.create(Exprs.Binary);
            expr.* = Exprs.Binary{
                .left = left,
                .operator = operator,
                .right = right,
            };
        }

        return expr;
    }

    fn term(self: *Parser) !*Expr {
        var expr = try self.factor();

        while (self.match(&.{ .MINUS, .PLUS })) {
            const operator = self.previous();
            const right = try self.factor();
            const left = expr;
            expr = try self.allocator.create(Exprs.Binary);
            expr.* = Exprs.Binary{
                .left = left,
                .operator = operator,
                .right = right,
            };
        }

        return expr;
    }

    fn factor(self: *Parser) !*Expr {
        var expr = try self.unary();

        while (self.match(&.{ .SLASH, .STAR })) {
            const operator = self.previous();
            const right = try self.unary();
            const left = expr;
            expr = try self.allocator.create(Exprs.Binary);
            expr.* = Exprs.Binary{
                .left = left,
                .operator = operator,
                .right = right,
            };
        }

        return expr;
    }

    fn unary(self: *Parser) !*Expr {
        if (self.match(&.{ .BANG, .MINUS })) {
            const operator = self.previous();
            const right = try self.unary();
            const expr = try self.allocator.create(Exprs.Binary);
            expr.* = Exprs.Unary{
                .operator = operator,
                .right = right,
            };
            return expr;
        }

        return try self.primary();
    }

    fn primary(self: *Parser) !*Expr {
        if (self.match(&.{.FALSE}))
            return self.allocator.create(Expr.Literal{ .value = .{
                .boolean = false,
            } });

        if (self.match(&.{.TRUE}))
            return self.allocator.create(Expr.Literal{ .value = .{
                .boolean = true,
            } });

        if (self.match(&.{.NIL}))
            return self.allocator.create(Expr.Literal{ .value = null });

        if (self.match(&.{ .NUMBER, .STRING })) return self.allocator.create(Exprs.Literal{
            .value = self.previous().literal,
        });

        if (self.match(&.{.LEFT_PAREN})) {
            const expr = try self.expression();
            _ = self.consume(.RIGHT_PAREN, "Expect ')' after expression.") catch self.synchronize();
            return Exprs.Grouping{ .expression = expr };
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
        self.advance();

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

            self.advance();
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
