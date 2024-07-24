const std = @import("std");
const Tokens = @import("tokens.zig");
const Exprs = @import("expr.zig");

const obj = Tokens.obj;
const Expr = Exprs.Expr;
const Token = Tokens.Token;
const TokenType = Tokens.TokenType;
const print = std.debug.print;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub const Parser = struct {
    tokens: ArrayList(Token),
    current: usize,

    pub fn init(tokens: ArrayList(Token)) Parser {
        return .{
            .tokens = tokens,
            .current = 0,
        };
    }

    fn expression(self: *Parser) Expr {
        return self.equality();
    }

    fn equality(self: *Parser) Expr {
        var expr = self.comparison();

        while (self.match([]TokenType{ .BANG_EQUAL, .EQUAL_EQUAL })) {
            const operator = self.previous();
            const right = self.comparison();
            expr = Exprs.Binary{
                .left = expr,
                .operator = operator,
                .right = right,
            };
        }
        return expr;
    }

    fn comparison(self: *Parser) Expr {
        var expr = self.term();

        while (self.match([]TokenType{
            .GREATER,
            .GREATER_EQUAL,
            .LESS,
            .LESS_EQUAL,
        })) {
            const operator = self.previous();
            const right = self.term();
            expr = Exprs.Binary{
                .left = expr,
                .operator = operator,
                .right = right,
            };
        }

        return expr;
    }

    fn term(self: *Parser) Expr {
        var expr = self.factor();

        while (self.match([]TokenType{ .MINUS, .PLUS })) {
            const operator = self.previous();
            const right = self.factor();
            expr = Exprs.Binary{
                .left = expr,
                .operator = operator,
                .right = right,
            };
        }

        return expr;
    }

    fn factor(self: *Parser) Expr {
        var expr = self.unary();

        while (self.match([]TokenType{ .SLASH, .STAR })) {
            const operator = self.previous();
            const right = self.unary();
            expr = Exprs.Binary{
                .left = expr,
                .operator = operator,
                .right = right,
            };
        }

        return expr;
    }

    fn unary(self: *Parser) Expr {
        if (self.match([]TokenType{ .BANG, .MINUS })) {
            const operator = self.previous();
            const right = self.unary();
            return Exprs.Unary{
                .operator = operator,
                .right = right,
            };
        }

        return self.primary();
    }

    fn primary(self: *Parser) Expr {
        if (self.match(&.{.FALSE})) return Exprs.Literal{
            .value = obj{ .boolean = false },
        };

        if (self.match(&.{.TRUE})) return Exprs.Literal{
            .value = obj{ .boolean = true },
        };

        if (self.match(&.{.NIL})) return Exprs.Literal{
            .value = null,
        };

        if (self.match(&.{.NUMBER})) return Exprs.Literal{
            .value = obj{ .num = self.previous().literal.?.num },
        };

        if (self.match(&.{.STRING})) return Exprs.Literal{
            .value = obj{ .num = self.previous().literal.?.str },
        };

        if (self.match(&.{.LEFT_PAREN})) {
            const expr = self.expression();
            self.consume(.RIGHT_PAREN, "Expect ')' after expression.");
            return Exprs.Grouping{ .expression = expr };
        }
    }

    fn match(self: *Parser, tTypes: []const TokenType) bool {
        for (tTypes) |tType| {
            if (self.check(tType)) {
                _ = self.advance();
                return true();
            }
        }

        return false;
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
