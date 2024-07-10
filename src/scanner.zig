const std = @import("std");
const Tokens = @import("tokens.zig");

const obj = Tokens.obj;
const Token = Tokens.Token;
const TokenType = Tokens.TokenType;
const print = std.debug.print;
const Allocator = std.mem.Allocator;
const fs = std.fs;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;

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
            print("Exiting...", .{});
            break;
        }
        buffer.reset();
    }
}

pub fn run(allocator: Allocator, source: []const u8) !void {
    var scanner = try Scanner.init(allocator, source);
    defer scanner.deinit();

    const tokens = try scanner.scanTokens();
    for (tokens.items) |token| {
        print("line: {}, tType: {s}, lexeme: {s}", .{ token.line, @tagName(token.tType), token.lexeme.? });

        if (token.literal) |literal| {
            switch (literal) {
                .str => |s| print(", literal: \"{s}\"", .{s}),
                .num => |n| print(", literal: {d}", .{n}),
            }
        }

        print("\n", .{});
    }
}

const Scanner = struct {
    source: []const u8,
    tokens: ArrayList(Token),
    start: usize,
    current: usize,
    line: usize,
    keywords: StringHashMap(TokenType),
    allocator: Allocator,

    pub fn init(allocator: Allocator, source: []const u8) !Scanner {
        var keywords = StringHashMap(TokenType).init(allocator);
        try keywords.put("and", .AND);
        try keywords.put("class", .CLASS);
        try keywords.put("else", .ELSE);
        try keywords.put("false", .FALSE);
        try keywords.put("for", .FOR);
        try keywords.put("fun", .FUN);
        try keywords.put("if", .IF);
        try keywords.put("nil", .NIL);
        try keywords.put("or", .OR);
        try keywords.put("print", .PRINT);
        try keywords.put("return", .RETURN);
        try keywords.put("super", .SUPER);
        try keywords.put("this", .THIS);
        try keywords.put("true", .TRUE);
        try keywords.put("var", .VAR);
        try keywords.put("while", .WHILE);
        return .{
            .source = source,
            .tokens = ArrayList(Token).init(allocator),
            .start = 0,
            .current = 0,
            .line = 1,
            .keywords = keywords,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Scanner) void {
        self.tokens.deinit();
        self.keywords.deinit();
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
            '(' => try self.addToken(.LEFT_PAREN, null),
            ')' => try self.addToken(.RIGHT_PAREN, null),
            '{' => try self.addToken(.LEFT_BRACE, null),
            '}' => try self.addToken(.RIGHT_BRACE, null),
            ',' => try self.addToken(.COMMA, null),
            '.' => try self.addToken(.DOT, null),
            '-' => try self.addToken(.MINUS, null),
            '+' => try self.addToken(.PLUS, null),
            ';' => try self.addToken(.SEMICOLON, null),
            '*' => try self.addToken(.STAR, null),
            '!' => try self.addToken(if (self.match('=')) .BANG_EQUAL else .BANG, null),
            '=' => try self.addToken(if (self.match('=')) .EQUAL_EQUAL else .EQUAL, null),
            '<' => try self.addToken(if (self.match('=')) .LESS_EQUAL else .LESS, null),
            '>' => try self.addToken(if (self.match('=')) .GREATER_EQUAL else .GREATER, null),
            '/' => {
                if (self.match('/')) {
                    while (self.peek() != '\n' and !self.isAtEnd())
                        _ = self.advance();
                } else if (self.match('*')) {
                    try self.multiLineComment();
                } else {
                    try self.addToken(.SLASH, null);
                }
            },
            ' ', '\r', '\t' => {},
            '\n' => self.line += 1,
            '"' => try self.string(),
            else => {
                if (isDigit(c)) {
                    try self.number();
                } else if (isAlpha(c)) {
                    try self.identifier();
                } else {
                    printerr(self.line, "Unexpected character.");
                }
            },
        }
    }

    // fn cStyle(self: *Scanner) void {
    //     while (self.peek() != '*' and self.peekNext() != '/' and !self.isAtEnd()) {
    //         if (self.peek() == '\n') self.line += 1;
    //         _ = self.advance();
    //     }
    //     if (!self.isAtEnd()) {
    //         _ = self.advance();
    //         _ = self.advance();
    //     }
    // }

    fn multiLineComment(self: *Scanner) !void {
        var nesting: usize = 1;
        while (nesting > 0 and !self.isAtEnd()) {
            if (self.peek() == '/' and self.peekNext() == '*') {
                _ = self.advance();
                _ = self.advance();
                nesting += 1;
            } else if (self.peek() == '*' and self.peekNext() == '/') {
                _ = self.advance();
                _ = self.advance();
                nesting -= 1;
            } else if (self.peek() == '\n') {
                self.line += 1;
                _ = self.advance();
            } else {
                _ = self.advance();
            }
        }
        if (self.isAtEnd() and nesting > 0) {
            printerr(self.line, "Unterminated multi-line comment.");
        }
    }

    fn identifier(self: *Scanner) !void {
        while (isAlphaNumeric(self.peek())) _ = self.advance();

        const text = self.source[self.start..self.current];
        const tType = self.keywords.get(text) orelse .IDENTIFIER;
        try self.addToken(tType, null);
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
        const value = self.source[self.start + 1 .. self.current - 1];
        try self.addToken(.STRING, obj{ .str = value });
    }

    fn number(self: *Scanner) !void {
        while (isDigit(self.peek())) _ = self.advance();

        if (self.peek() == '.' and isDigit(self.peekNext())) {
            _ = self.advance();
            while (isDigit(self.peek())) _ = self.advance();
        }
        const value = self.source[self.start..self.current];
        const num = try std.fmt.parseFloat(f64, value);
        try self.addToken(.NUMBER, obj{ .num = num });
    }

    fn isAtEnd(self: *Scanner) bool {
        return self.current >= self.source.len;
    }

    fn isDigit(c: u8) bool {
        return c >= '0' and c <= '9';
    }

    fn isAlpha(c: u8) bool {
        return (c >= 'a' and c <= 'z') or
            (c >= 'A' and c <= 'Z') or
            c == '_';
    }

    fn isAlphaNumeric(c: u8) bool {
        return isAlpha(c) or isDigit(c);
    }

    fn advance(self: *Scanner) u8 {
        self.current += 1;
        return self.source[self.current - 1];
    }

    fn addToken(self: *Scanner, tType: TokenType, literal: ?obj) !void {
        const lexeme = self.source[self.start..self.current];
        const token = Token{
            .tType = tType,
            .lexeme = lexeme,
            .line = self.line,
            .literal = literal,
        };
        try self.tokens.append(token);
    }

    fn match(self: *Scanner, expected: u8) bool {
        if (self.isAtEnd() or self.source[self.current] != expected) return false;
        self.current += 1;
        return true;
    }

    fn peek(self: *Scanner) u8 {
        return if (self.isAtEnd()) 0 else self.source[self.current];
    }

    fn peekNext(self: *Scanner) u8 {
        return if (self.current + 1 >= self.source.len) 0 else self.source[self.current + 1];
    }

    fn printerr(line: usize, message: []const u8) void {
        print("Error {s} on line {}\n", .{ message, line });
    }
};
