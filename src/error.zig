const std = @import("std");
const print = std.debug.print;
const Tokens = @import("tokens.zig");

const Token = Tokens.Token;
const TokenType = Tokens.TokenType;

pub const ParseError = error{
    MissingParen,
    ExpectExpr,
    GenericError,
};

pub const RuntimeError = error{
    IncompatibleTypes,
    InvalidOperation,
    NullType,
};

pub const Error = struct {
    pub fn printerr(value: anytype, message: []const u8) void {
        switch (@TypeOf(value)) {
            usize => {
                print("[line {}] Error : {s}\n", .{ value, message });
            },
            Token => {
                if (value.tType == .EOF) {
                    print("[line {}] Error at end : {s}\n", .{ value.line, message });
                } else {
                    print("[line {}] Error at '{s}' : {s}\n", .{ value.line, value.lexeme.?, message });
                }
            },
            else => {
                print("invalid value type", .{});
            },
        }
    }
};
