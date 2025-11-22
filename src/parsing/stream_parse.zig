const std = @import("std");
const value_mod = @import("../core/value.zig");
const lexer_mod = @import("lexer.zig");

pub const Error = value_mod.Error;

/// Token types emitted by the streaming parser
pub const TokenType = enum {
    object_begin,
    object_end,
    array_begin,
    array_end,
    string,
    number,
    true_value,
    false_value,
    null_value,
    field_name,
};

/// A token emitted during streaming parse
pub const Token = struct {
    type: TokenType,
    /// String data for string/number/field_name tokens. Points into the reader's buffer.
    /// For numbers, this is the raw text representation.
    /// For strings, this is the unescaped content (allocated if needed).
    data: []const u8 = &.{},
    /// True if data was allocated and needs to be freed
    allocated: bool = false,
    line: usize,
    column: usize,
};

/// Streaming JSON parser that reads from any reader and emits tokens
pub fn StreamParser(comptime ReaderType: type) type {
    return struct {
        lexer: lexer_mod.BufferedLexer(ReaderType),
        allocator: std.mem.Allocator,
        state_stack: std.ArrayList(State),
        peeked_token: ?Token,
        finished: bool,

        const Self = @This();
        const State = enum {
            array_start,
            array_value,
            object_start,
            object_key,
            object_colon,
            object_value,
        };

        pub fn init(reader: ReaderType, allocator: std.mem.Allocator) Self {
            const buffered_input = lexer_mod.BufferedInput(ReaderType).init(reader);
            return .{
                .lexer = lexer_mod.BufferedLexer(ReaderType).init(buffered_input, allocator),
                .allocator = allocator,
                .state_stack = .{},
                .peeked_token = null,
                .finished = false,
            };
        }

        pub fn deinit(self: *Self) void {
            self.lexer.deinit();
            self.state_stack.deinit(self.allocator);
        }

        inline fn advancePos(self: *Self) void {
            if (self.lexer.input.peek()) |c| {
                self.lexer.input.advance();
                if (c == '\n') {
                    self.lexer.position.line += 1;
                    self.lexer.position.column = 1;
                } else {
                    self.lexer.position.column += 1;
                }
                self.lexer.position.byte_offset += 1;
            }
        }

        /// Get the next token. Returns null when parsing is complete.
        pub fn next(self: *Self) !?Token {
            if (self.peeked_token) |token| {
                self.peeked_token = null;
                return token;
            }

            if (self.finished) return null;

            try self.lexer.skipWhitespace();

            if (!(try self.lexer.input.hasMore(self.allocator))) {
                if (self.state_stack.items.len > 0) {
                    return Error.UnexpectedEnd;
                }
                self.finished = true;
                return null;
            }

            const c = self.lexer.input.peek() orelse {
                if (self.state_stack.items.len > 0) {
                    return Error.UnexpectedEnd;
                }
                self.finished = true;
                return null;
            };
            const token_line = self.lexer.position.line;
            const token_column = self.lexer.position.column;

            return switch (c) {
                '{' => blk: {
                    try self.state_stack.append(self.allocator, .object_start);
                    self.advancePos();
                    break :blk Token{
                        .type = .object_begin,
                        .line = token_line,
                        .column = token_column,
                    };
                },
                '}' => blk: {
                    if (self.state_stack.items.len == 0) return Error.InvalidSyntax;
                    const state = self.state_stack.pop();
                    if (state != .object_start and state != .object_key and state != .object_value) {
                        return Error.InvalidSyntax;
                    }
                    self.advancePos();
                    try self.updateStateAfterValue();
                    break :blk Token{
                        .type = .object_end,
                        .line = token_line,
                        .column = token_column,
                    };
                },
                '[' => blk: {
                    try self.state_stack.append(self.allocator, .array_start);
                    self.advancePos();
                    break :blk Token{
                        .type = .array_begin,
                        .line = token_line,
                        .column = token_column,
                    };
                },
                ']' => blk: {
                    if (self.state_stack.items.len == 0) return Error.InvalidSyntax;
                    const state = self.state_stack.pop();
                    if (state != .array_start and state != .array_value) {
                        return Error.InvalidSyntax;
                    }
                    self.advancePos();
                    try self.updateStateAfterValue();
                    break :blk Token{
                        .type = .array_end,
                        .line = token_line,
                        .column = token_column,
                    };
                },
                ':' => blk: {
                    if (self.state_stack.items.len == 0) return Error.InvalidSyntax;
                    const idx = self.state_stack.items.len - 1;
                    if (self.state_stack.items[idx] != .object_colon) {
                        return Error.InvalidSyntax;
                    }
                    self.state_stack.items[idx] = .object_value;
                    self.advancePos();
                    break :blk try self.next();
                },
                ',' => blk: {
                    if (self.state_stack.items.len == 0) return Error.InvalidSyntax;
                    const idx = self.state_stack.items.len - 1;
                    const state = self.state_stack.items[idx];
                    if (state == .array_value) {
                        self.state_stack.items[idx] = .array_start;
                    } else if (state == .object_value) {
                        self.state_stack.items[idx] = .object_key;
                    } else {
                        return Error.InvalidSyntax;
                    }
                    self.advancePos();
                    break :blk try self.next();
                },
                '"' => blk: {
                    const is_field_name = if (self.state_stack.items.len > 0) blk2: {
                        const state = self.state_stack.items[self.state_stack.items.len - 1];
                        break :blk2 state == .object_start or state == .object_key;
                    } else false;

                    const str = try self.lexer.parseString();

                    if (is_field_name) {
                        const idx = self.state_stack.items.len - 1;
                        self.state_stack.items[idx] = .object_colon;
                        break :blk Token{
                            .type = .field_name,
                            .data = str.data,
                            .allocated = str.allocated,
                            .line = token_line,
                            .column = token_column,
                        };
                    } else {
                        try self.updateStateAfterValue();
                        break :blk Token{
                            .type = .string,
                            .data = str.data,
                            .allocated = str.allocated,
                            .line = token_line,
                            .column = token_column,
                        };
                    }
                },
                'n' => blk: {
                    try self.lexer.expectLiteral("null");
                    try self.updateStateAfterValue();
                    break :blk Token{
                        .type = .null_value,
                        .line = token_line,
                        .column = token_column,
                    };
                },
                't' => blk: {
                    try self.lexer.expectLiteral("true");
                    try self.updateStateAfterValue();
                    break :blk Token{
                        .type = .true_value,
                        .line = token_line,
                        .column = token_column,
                    };
                },
                'f' => blk: {
                    try self.lexer.expectLiteral("false");
                    try self.updateStateAfterValue();
                    break :blk Token{
                        .type = .false_value,
                        .line = token_line,
                        .column = token_column,
                    };
                },
                '-', '0'...'9' => blk: {
                    const num = try self.lexer.parseNumber();
                    try self.updateStateAfterValue();
                    break :blk Token{
                        .type = .number,
                        .data = num,
                        .allocated = true,
                        .line = token_line,
                        .column = token_column,
                    };
                },
                else => Error.InvalidSyntax,
            };
        }

        fn updateStateAfterValue(self: *Self) !void {
            if (self.state_stack.items.len > 0) {
                const idx = self.state_stack.items.len - 1;
                const state = self.state_stack.items[idx];
                if (state == .array_start) {
                    self.state_stack.items[idx] = .array_value;
                } else if (state == .object_value) {
                    // Will transition to object_key after comma
                }
            }
        }
    };
}

/// Convenience function to create a stream parser from a reader
pub fn streamParser(reader: anytype, allocator: std.mem.Allocator) StreamParser(@TypeOf(reader)) {
    return StreamParser(@TypeOf(reader)).init(reader, allocator);
}
