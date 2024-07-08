const std = @import("std");
const Tokens = @import("tokens.zig");

const Token = Tokens.Token;
const TokenType = Tokens.TokenType;
const print = std.debug.print;
const Allocator = std.mem.Allocator;
const fs = std.fs;
const ArrayList = std.ArrayList;
const AutoHashMap = std.AutoHashMap;

pub fn runFile(allocator: Allocator, path: []const u8) !void {
    const file = try fs.cwd().openFile(path, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const buffer = try allocator.alloc(u8, file_size);
    defer allocator.free(buffer);
    _ = try file.readAll(buffer);
    _ = try run(buffer);
}

pub fn runPrompt(allocator: Allocator) !void {
    var input: [1024]u8 = undefined;
    const stdin = std.io.getStdIn();
    const reader = stdin.reader();
    var buffer = std.io.fixedBufferStream(&input);
    const writer = buffer.writer();

    while (true) {
        print(">>> ", .{});
        input = undefined;
        if (reader.streamUntilDelimiter(
            writer,
            '\n',
            buffer.buffer.len,
        )) {
            _ = try writer.write("\n");
            const n = try buffer.getPos();
            const prompt = try allocator.dupe(u8, buffer.buffer[0..n]);
            _ = try run(prompt);
        } else |_| {
            print("Existing...", .{});
            break;
        }
        buffer.reset();
    }
}

pub fn run(source: []const u8) !void {
    print("{s}", .{source});
}

const Scanner = struct {
    source: []const u8 = undefined,
    tokens: ArrayList(Token) = undefined,
    start: usize = undefined,
    current: usize = undefined,
    line: usize,

    fn init(self: Scanner, source: []const u8) *Scanner {
        self.source = source;
    }

    fn scanTokens(self: Scanner) void {
        while (!isAtEnd()) {
            self.start = self.current;
        }
    }

    fn scanToken(self: Scanner) void {
        const c = self.advance();
        switch (c) {
            '(' => self.addToken(TokenType.LEFT_PAREN, null),
            ')' => self.addToken(TokenType.RIGHT_PAREN, null),
            '{' => self.addToken(TokenType.LEFT_BRACE, null),
            '}' => self.addToken(TokenType.RIGHT_BRACE, null),
            ',' => self.addToken(TokenType.COMMA, null),
            '.' => self.addToken(TokenType.DOT, null),
            '-' => self.addToken(TokenType.MINUS, null),
            '+' => self.addToken(TokenType.PLUS, null),
            ';' => self.addToken(TokenType.SEMICOLON, null),
            '*' => self.addToken(TokenType.STAR, null),
            '!' => self.addToken(if (self.match('=')) TokenType.BANG_EQUAL else TokenType.BANG, null),
            '=' => self.addToken(if (self.match('=')) TokenType.EQUAL_EQUAL else TokenType.EQUAL, null),
            '<' => self.addToken(if (self.match('=')) TokenType.LESS_EQUAL else TokenType.LESS, null),
            '>' => self.addToken(if (self.match('=')) TokenType.GREATER_EQUAL else TokenType.GREATER, null),
            '/' => {
                if (self.match('/')) {
                    while (self.peek() != '\n' and !self.isAtEnd()) {
                        _ = self.advance();
                    }
                } else {
                    addToken(TokenType.SLASH, null);
                }
            },
            ' ', '\r', '\t' => {},
            '\n' => {
                self.line += 1;
            },
            else => {},
        }
    }

    fn isAtEnd(self: Scanner) bool {
        return self.current >= self.source.len;
    }

    fn advance(self: Scanner) u8 {
        self.current += 1;
        return self.source[self.current - 1];
    }

    fn addToken(self: Scanner, tType: TokenType, literal: ?[]const u8) void {
        var token = Token{
            .tType = tType,
            .lexeme = self.source[self.start..self.current],
            .line = self.line,
        };

        if (literal) |str| {
            token.literal = str;
        } else {
            token.literal = null;
        }
        self.tokens.append(token);
    }

    fn match(self: Scanner, char: u8) bool {
        if (self.isAtEnd()) return false;
        if (self.source[self.current] != char) return false;

        self.current += 1;
        return true;
    }

    fn peek(self: Scanner) u8 {
        if (self.isAtEnd()) return 0;
        return self.source[self.current];
    }
};
