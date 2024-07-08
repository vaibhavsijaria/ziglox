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
    _ = try run(allocator, buffer);
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
            _ = try run(allocator, prompt);
        } else |_| {
            print("Existing...", .{});
            break;
        }
        buffer.reset();
    }
}

pub fn run(allocator: Allocator, source: []const u8) !void {
    // print("{s}", .{source});
    var scanner = Scanner.init(allocator, source);
    defer scanner.deinit();
    _ = try scanner.scanTokens();
    var tokens = scanner.tokens;
    while (tokens.popOrNull()) |token| {
        print("line: {}, tType: {s}, text: {s}\n", .{ token.line, @tagName(token.tType), token.lexeme.? });
    }
}

const Scanner = struct {
    source: []const u8,
    tokens: ArrayList(Token),
    start: usize,
    current: usize,
    line: usize,

    pub fn init(allocator: Allocator, source: []const u8) Scanner {
        return .{
            .source = source,
            .tokens = ArrayList(Token).init(allocator),
            .start = 0,
            .current = 0,
            .line = 1,
        };
    }

    pub fn deinit(self: *Scanner) void {
        self.tokens.deinit();
    }

    pub fn scanTokens(self: *Scanner) !ArrayList(Token) {
        while (!self.isAtEnd()) {
            self.start = self.current;
            try self.scanToken();
        }

        try self.tokens.append(Token{
            .tType = TokenType.EOF,
            .lexeme = "",
            .line = self.line,
            .literal = null,
        });

        return self.tokens;
    }

    fn scanToken(self: *Scanner) !void {
        const c = self.advance();
        switch (c) {
            '(' => try self.addToken(TokenType.LEFT_PAREN, null),
            ')' => try self.addToken(TokenType.RIGHT_PAREN, null),
            '{' => try self.addToken(TokenType.LEFT_BRACE, null),
            '}' => try self.addToken(TokenType.RIGHT_BRACE, null),
            ',' => try self.addToken(TokenType.COMMA, null),
            '.' => try self.addToken(TokenType.DOT, null),
            '-' => try self.addToken(TokenType.MINUS, null),
            '+' => try self.addToken(TokenType.PLUS, null),
            ';' => try self.addToken(TokenType.SEMICOLON, null),
            '*' => try self.addToken(TokenType.STAR, null),
            '!' => try self.addToken(if (self.match('=')) TokenType.BANG_EQUAL else TokenType.BANG, null),
            '=' => try self.addToken(if (self.match('=')) TokenType.EQUAL_EQUAL else TokenType.EQUAL, null),
            '<' => try self.addToken(if (self.match('=')) TokenType.LESS_EQUAL else TokenType.LESS, null),
            '>' => try self.addToken(if (self.match('=')) TokenType.GREATER_EQUAL else TokenType.GREATER, null),
            '/' => {
                if (self.match('/')) {
                    while (self.peek() != '\n' and !self.isAtEnd()) {
                        _ = self.advance();
                    }
                } else {
                    try self.addToken(TokenType.SLASH, null);
                }
            },
            ' ', '\r', '\t' => {},
            '\n' => {
                self.line += 1;
            },
            '"' => try self.string(),
            else => {
                if (isDigit(c)) {
                    try self.number();
                } else {
                    printerr(self.line, "Unexpected character.");
                }
            },
        }
    }

    fn string(self: *Scanner) !void {
        while (self.peek() != '"' and !self.isAtEnd()) {
            if (self.peek() == '\n') self.line += 1;
            _ = self.advance();
        }
        if (self.isAtEnd()) {
            printerr(self.line, "Unterminated string.");
            return;
        }
        _ = self.advance();
        try self.addToken(
            TokenType.STRING,
            self.source[self.start + 1 .. self.current - 1],
        );
    }

    fn number(self: *Scanner) !void {
        while (self.isDigit(self.peek())) self.advance();

        if (self.peek() == '.' and self.isDigit(self.peaknext())) {
            self.advance();
            while (self.isDigit(self.peek())) self.advance();
        }
        const num = std.fmt.parseFloat(
            f64,
            self.source[self.start..self.current],
        );
        try self.addToken(TokenType.NUMBER, num);
    }

    fn isAtEnd(self: *Scanner) bool {
        return self.current >= self.source.len;
    }

    fn isDigit(c: u8) bool {
        return c >= '0' and c <= 9;
    }

    fn advance(self: *Scanner) u8 {
        self.current += 1;
        return self.source[self.current - 1];
    }

    fn addToken(self: *Scanner, tType: TokenType, literal: ?[]const u8) !void {
        const token = Token{
            .tType = tType,
            .lexeme = self.source[self.start..self.current],
            .line = self.line,
            .literal = literal,
        };
        try self.tokens.append(token);
    }

    fn match(self: *Scanner, expected: u8) bool {
        if (self.isAtEnd()) return false;
        if (self.source[self.current] != expected) return false;
        self.current += 1;
        return true;
    }

    fn peek(self: *Scanner) u8 {
        if (self.isAtEnd()) return 0;
        return self.source[self.current];
    }

    fn peekNext(self: *Scanner) u8 {
        if (self.current + 1 >= self.source.len) return 0;
        return self.source[self.current + 1];
    }

    fn printerr(line: usize, message: []const u8) void {
        print("Error {s} on line {}\n", .{ message, line });
    }
};
