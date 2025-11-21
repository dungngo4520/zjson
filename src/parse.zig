const std = @import("std");
const value_mod = @import("value.zig");

pub const Error = value_mod.Error;
pub const Value = value_mod.Value;
pub const Pair = value_mod.Pair;
pub const ParseOptions = value_mod.ParseOptions;
pub const ParseResult = value_mod.ParseResult;

threadlocal var last_parse_error_info: ?value_mod.ParseErrorInfo = null;

pub fn lastParseErrorInfo() ?value_mod.ParseErrorInfo {
    return last_parse_error_info;
}

pub fn parseToArena(input: []const u8, base_allocator: std.mem.Allocator, options: ParseOptions) Error!ParseResult {
    var arena = std.heap.ArenaAllocator.init(base_allocator);
    errdefer arena.deinit();

    last_parse_error_info = null;

    var parser = FastParser{
        .input = input,
        .pos = 0,
        .line = 1,
        .column = 1,
        .arena = arena.allocator(),
        .options = options,
        .last_error_info = null,
    };

    const value = try parser.parseValue();

    // Check for trailing content
    parser.skipWhitespace();
    if (parser.pos < parser.input.len) {
        return parser.fail(Error.TrailingCharacters);
    }

    return ParseResult{
        .value = value,
        .arena = arena,
        .error_info = null,
    };
}

/// Fast parser using arena allocator
const FastParser = struct {
    input: []const u8,
    pos: usize,
    line: usize,
    column: usize,
    arena: std.mem.Allocator,
    options: ParseOptions,
    last_error_info: ?value_mod.ParseErrorInfo = null,

    fn parseValue(self: *FastParser) Error!Value {
        self.skipWhitespace();
        if (self.pos >= self.input.len) return self.fail(Error.UnexpectedEnd);

        return switch (self.input[self.pos]) {
            'n' => self.parseNull(),
            't', 'f' => self.parseBool(),
            '"' => self.parseString(),
            '[' => self.parseArray(),
            '{' => self.parseObject(),
            '-', '0'...'9' => self.parseNumber(),
            else => self.fail(Error.InvalidSyntax),
        };
    }

    inline fn advance(self: *FastParser, count: usize) void {
        var moved: usize = 0;
        while (moved < count and self.pos < self.input.len) : (moved += 1) {
            const c = self.input[self.pos];
            self.pos += 1;
            if (c == '\n') {
                self.line += 1;
                self.column = 1;
            } else {
                self.column += 1;
            }
        }
    }

    inline fn fail(self: *FastParser, err: Error) Error {
        const info = value_mod.ParseErrorInfo{
            .byte_offset = self.pos,
            .line = self.line,
            .column = self.column,
            .context = self.sliceContext(),
        };
        self.last_error_info = info;
        last_parse_error_info = info;
        return err;
    }

    fn sliceContext(self: *FastParser) []const u8 {
        const window: usize = 24;
        const start = if (self.pos > window) self.pos - window else 0;
        const end = @min(self.input.len, self.pos + window);
        return self.input[start..end];
    }

    inline fn parseNull(self: *FastParser) Error!Value {
        if (self.pos + 4 > self.input.len or
            !std.mem.eql(u8, self.input[self.pos .. self.pos + 4], "null"))
        {
            return self.fail(Error.InvalidSyntax);
        }
        self.advance(4);
        return Value.Null;
    }

    inline fn parseBool(self: *FastParser) Error!Value {
        if (self.pos + 4 <= self.input.len and
            std.mem.eql(u8, self.input[self.pos .. self.pos + 4], "true"))
        {
            self.advance(4);
            return Value{ .Bool = true };
        } else if (self.pos + 5 <= self.input.len and
            std.mem.eql(u8, self.input[self.pos .. self.pos + 5], "false"))
        {
            self.advance(5);
            return Value{ .Bool = false };
        }
        return self.fail(Error.InvalidSyntax);
    }

    fn parseNumber(self: *FastParser) Error!Value {
        const start = self.pos;

        // Optional minus
        if (self.pos < self.input.len and self.input[self.pos] == '-') {
            self.advance(1);
        }

        if (self.pos >= self.input.len or !std.ascii.isDigit(self.input[self.pos])) {
            return self.fail(Error.InvalidNumber);
        }

        // Fast number scanning
        while (self.pos < self.input.len) {
            const c = self.input[self.pos];
            if (std.ascii.isDigit(c) or c == '.' or c == 'e' or c == 'E' or c == '+' or c == '-') {
                self.advance(1);
            } else {
                break;
            }
        }

        return Value{ .Number = self.input[start..self.pos] };
    }

    fn parseString(self: *FastParser) Error!Value {
        if (self.input[self.pos] != '"') return self.fail(Error.InvalidSyntax);
        self.advance(1);

        const start = self.pos;
        const result = self.scanString() catch |err| switch (err) {
            error.UnexpectedEnd => return self.fail(Error.UnexpectedEnd),
        };

        if (result.has_escapes) {
            return Value{ .String = try self.unescapeString(start, result.end) };
        } else {
            // Zero-copy string
            return Value{ .String = self.input[start..result.end] };
        }
    }

    const StringScanResult = struct {
        end: usize,
        has_escapes: bool,
    };

    fn scanString(self: *FastParser) !StringScanResult {
        var has_escapes = false;

        while (self.pos < self.input.len) {
            const c = self.input[self.pos];

            if (c == '"') {
                const end = self.pos;
                self.advance(1);
                return StringScanResult{ .end = end, .has_escapes = has_escapes };
            } else if (c == '\\') {
                has_escapes = true;
                self.advance(1);
                if (self.pos >= self.input.len) return error.UnexpectedEnd;

                if (self.input[self.pos] == 'u') {
                    self.advance(5); // Skip u + 4 hex digits
                } else {
                    self.advance(1);
                }
            } else {
                self.advance(1);
            }
        }

        return error.UnexpectedEnd;
    }

    fn unescapeString(self: *FastParser, start: usize, end: usize) ![]const u8 {
        var result = try std.ArrayList(u8).initCapacity(self.arena, end - start);

        var i = start;
        while (i < end) {
            if (self.input[i] == '\\') {
                i += 1;
                if (i >= end) return self.fail(Error.InvalidEscape);

                switch (self.input[i]) {
                    '"' => try result.append(self.arena, '"'),
                    '\\' => try result.append(self.arena, '\\'),
                    '/' => try result.append(self.arena, '/'),
                    'b' => try result.append(self.arena, '\x08'),
                    'f' => try result.append(self.arena, '\x0C'),
                    'n' => try result.append(self.arena, '\n'),
                    'r' => try result.append(self.arena, '\r'),
                    't' => try result.append(self.arena, '\t'),
                    'u' => {
                        i += 1;
                        if (i + 3 >= end) return self.fail(Error.InvalidEscape);
                        const hex = self.input[i .. i + 4];
                        const codepoint = std.fmt.parseInt(u16, hex, 16) catch return self.fail(Error.InvalidEscape);
                        try result.append(self.arena, @intCast(codepoint));
                        i += 3;
                    },
                    else => return self.fail(Error.InvalidEscape),
                }
                i += 1;
            } else {
                // Batch copy normal characters
                const batch_start = i;
                while (i < end and self.input[i] != '\\') {
                    i += 1;
                }
                try result.appendSlice(self.arena, self.input[batch_start..i]);
            }
        }

        return result.toOwnedSlice(self.arena);
    }

    fn parseArray(self: *FastParser) Error!Value {
        if (self.input[self.pos] != '[') return self.fail(Error.InvalidSyntax);
        self.advance(1);
        self.skipWhitespace();

        // Empty array
        if (self.pos < self.input.len and self.input[self.pos] == ']') {
            self.advance(1);
            return Value{ .Array = &.{} };
        }

        var items = try std.ArrayList(Value).initCapacity(self.arena, 8);

        while (true) {
            const item = try self.parseValue();
            try items.append(self.arena, item);

            self.skipWhitespace();
            if (self.pos >= self.input.len) return self.fail(Error.UnexpectedEnd);

            if (self.input[self.pos] == ']') {
                self.advance(1);
                break;
            } else if (self.input[self.pos] == ',') {
                self.advance(1);
                self.skipWhitespace();
                // Handle trailing comma
                if (self.options.allow_trailing_commas and
                    self.pos < self.input.len and self.input[self.pos] == ']')
                {
                    self.advance(1);
                    break;
                }
            } else {
                return self.fail(Error.InvalidSyntax);
            }
        }

        return Value{ .Array = try items.toOwnedSlice(self.arena) };
    }

    fn parseObject(self: *FastParser) Error!Value {
        if (self.input[self.pos] != '{') return self.fail(Error.InvalidSyntax);
        self.advance(1);
        self.skipWhitespace();

        // Empty object
        if (self.pos < self.input.len and self.input[self.pos] == '}') {
            self.advance(1);
            return Value{ .Object = &.{} };
        }

        var fields = try std.ArrayList(Pair).initCapacity(self.arena, 8);

        while (true) {
            self.skipWhitespace();
            if (self.pos >= self.input.len) return self.fail(Error.UnexpectedEnd);

            // Parse key
            const key_value = try self.parseString();
            const key = switch (key_value) {
                .String => |s| s,
                else => return self.fail(Error.InvalidSyntax),
            };

            self.skipWhitespace();
            if (self.pos >= self.input.len or self.input[self.pos] != ':') return self.fail(Error.InvalidSyntax);
            self.advance(1);

            // Parse value
            const value = try self.parseValue();
            try fields.append(self.arena, Pair{ .key = key, .value = value });

            self.skipWhitespace();
            if (self.pos >= self.input.len) return self.fail(Error.UnexpectedEnd);

            if (self.input[self.pos] == '}') {
                self.advance(1);
                break;
            } else if (self.input[self.pos] == ',') {
                self.advance(1);
                // Handle trailing comma
                self.skipWhitespace();
                if (self.options.allow_trailing_commas and
                    self.pos < self.input.len and self.input[self.pos] == '}')
                {
                    self.advance(1);
                    break;
                }
            } else {
                return self.fail(Error.InvalidSyntax);
            }
        }

        return Value{ .Object = try fields.toOwnedSlice(self.arena) };
    }

    inline fn skipWhitespace(self: *FastParser) void {
        while (self.pos < self.input.len) {
            const c = self.input[self.pos];
            if (std.ascii.isWhitespace(c)) {
                self.advance(1);
            } else if (self.options.allow_comments and c == '/') {
                if (self.pos + 1 < self.input.len) {
                    if (self.input[self.pos + 1] == '/') {
                        // Line comment - skip to end of line
                        self.advance(2);
                        while (self.pos < self.input.len and self.input[self.pos] != '\n') {
                            self.advance(1);
                        }
                    } else if (self.input[self.pos + 1] == '*') {
                        // Block comment - skip to */
                        self.advance(2);
                        while (self.pos + 1 < self.input.len) {
                            if (self.input[self.pos] == '*' and self.input[self.pos + 1] == '/') {
                                self.advance(2);
                                break;
                            }
                            self.advance(1);
                        }
                    } else {
                        break;
                    }
                } else {
                    break;
                }
            } else {
                break;
            }
        }
    }
};
