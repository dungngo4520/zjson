const std = @import("std");
const value_mod = @import("value.zig");

pub const Error = value_mod.Error;
pub const Value = value_mod.Value;
pub const Pair = value_mod.Pair;
pub const ParseOptions = value_mod.ParseOptions;
pub const ParseError = value_mod.ParseError;

pub fn parse(input: []const u8, allocator: std.mem.Allocator, options: ParseOptions) Error!Value {
    var parser = Parser{
        .input = input,
        .pos = 0,
        .allocator = allocator,
        .options = options,
        .line = 1,
        .column = 1,
    };
    const result = try parser.parseValue();

    // Check for trailing characters if not explicitly allowed
    parser.skipWhitespaceAndComments();
    if (parser.pos < parser.input.len) {
        // Free allocated memory before returning error
        freeValue(result, allocator);
        return Error.TrailingCharacters;
    }

    return result;
}

/// Parse with detailed error reporting including line and column
pub fn parseWithError(input: []const u8, allocator: std.mem.Allocator, options: ParseOptions) Error!Value {
    var parser = Parser{
        .input = input,
        .pos = 0,
        .allocator = allocator,
        .options = options,
        .line = 1,
        .column = 1,
    };
    const result = try parser.parseValue();

    // Check for trailing characters if not explicitly allowed
    parser.skipWhitespaceAndComments();
    if (parser.pos < parser.input.len) {
        // Free allocated memory before returning error
        freeValue(result, allocator);
        return Error.TrailingCharacters;
    }

    return result;
}

/// Get detailed error information for the last error
pub fn getLastParseError(input: []const u8, pos: usize) ParseError {
    var line: usize = 1;
    var column: usize = 1;

    for (0..@min(pos, input.len)) |i| {
        if (input[i] == '\n') {
            line += 1;
            column = 1;
        } else {
            column += 1;
        }
    }

    return ParseError{
        .error_type = Error.InvalidSyntax,
        .pos = pos,
        .line = line,
        .column = column,
    };
}

pub fn freeValue(val: Value, allocator: std.mem.Allocator) void {
    switch (val) {
        .String => {
            // Borrowed from input - don't free
        },
        .StringOwned => |s| {
            // Allocated string - free it
            allocator.free(s);
        },
        .Number => {
            // Number is a reference to input, not allocated
        },
        .Array => |arr| {
            for (arr) |item| {
                freeValue(item, allocator);
            }
            allocator.free(arr);
        },
        .Object => |obj| {
            for (obj) |pair| {
                freeValue(pair.value, allocator);
                // Keys are borrowed from input (zero-copy) - don't free
            }
            allocator.free(obj);
        },
        else => {},
    }
}

const Parser = struct {
    input: []const u8,
    pos: usize,
    allocator: std.mem.Allocator,
    options: ParseOptions,
    line: usize,
    column: usize,

    // Estimate array/object size based on remaining JSON
    fn estimateSize(self: *Parser) usize {
        const remaining = self.input.len - self.pos;
        // Conservative heuristic: smaller initial allocation
        return @max(2, @min(32, remaining / 25));
    }

    inline fn parseValue(self: *Parser) Error!Value {
        self.skipWhitespaceAndComments();
        if (self.pos >= self.input.len) return Error.UnexpectedEnd;

        const c = self.input[self.pos];
        return switch (c) {
            'n' => self.parseNull(),
            't', 'f' => self.parseBool(),
            '"' => self.parseString(),
            '[' => self.parseArray(),
            '{' => self.parseObject(),
            '-', '0'...'9' => self.parseNumber(),
            else => Error.InvalidSyntax,
        };
    }

    inline fn parseNull(self: *Parser) Error!Value {
        if (self.pos + 4 > self.input.len or !std.mem.eql(u8, self.input[self.pos .. self.pos + 4], "null")) {
            return Error.InvalidSyntax;
        }
        self.pos += 4;
        return Value.Null;
    }

    inline fn parseBool(self: *Parser) Error!Value {
        if (self.pos + 4 <= self.input.len and std.mem.eql(u8, self.input[self.pos .. self.pos + 4], "true")) {
            self.pos += 4;
            return Value{ .Bool = true };
        } else if (self.pos + 5 <= self.input.len and std.mem.eql(u8, self.input[self.pos .. self.pos + 5], "false")) {
            self.pos += 5;
            return Value{ .Bool = false };
        }
        return Error.InvalidSyntax;
    }

    fn parseString(self: *Parser) Error!Value {
        if (self.input[self.pos] != '"') return Error.InvalidSyntax;
        self.pos += 1;

        const start = self.pos;
        var has_escapes = false;

        // First pass: scan to find end and check for escapes
        while (self.pos < self.input.len) {
            const c = self.input[self.pos];
            if (c == '"') {
                // Found end quote
                const str_slice = self.input[start..self.pos];
                self.pos += 1;

                if (!has_escapes) {
                    // Zero-copy: return slice of input buffer
                    return Value{ .String = str_slice };
                } else {
                    // Need to process escapes - allocate and unescape
                    return try self.parseStringWithEscapes(start, self.pos - 1);
                }
            } else if (c == '\\') {
                has_escapes = true;
                self.pos += 1;
                if (self.pos >= self.input.len) return Error.UnexpectedEnd;
                // Skip the escaped character
                if (self.input[self.pos] == 'u') {
                    self.pos += 5; // Skip 'u' + 4 hex digits
                } else {
                    self.pos += 1;
                }
            } else {
                self.pos += 1;
            }
        }
        return Error.UnexpectedEnd;
    }

    fn parseStringWithEscapes(self: *Parser, start: usize, end: usize) Error!Value {
        var result = std.array_list.Managed(u8).init(self.allocator);
        errdefer result.deinit();

        // Pre-allocate based on original length
        try result.ensureTotalCapacity(end - start);

        var i = start;
        while (i < end) {
            // Batch copy non-escape characters
            const batch_start = i;
            while (i < end and self.input[i] != '\\') {
                i += 1;
            }

            if (i > batch_start) {
                // Copy the batch of normal characters
                try result.appendSlice(self.input[batch_start..i]);
            }

            if (i >= end) break;

            // Handle escape sequence
            const c = self.input[i];
            if (c == '\\') {
                i += 1;
                if (i >= end) return Error.UnexpectedEnd;
                switch (self.input[i]) {
                    '"' => try result.append('"'),
                    '\\' => try result.append('\\'),
                    '/' => try result.append('/'),
                    'b' => try result.append('\x08'),
                    'f' => try result.append('\x0C'),
                    'n' => try result.append('\n'),
                    'r' => try result.append('\r'),
                    't' => try result.append('\t'),
                    'u' => {
                        i += 1;
                        if (i + 3 >= end) return Error.InvalidEscape;
                        const hex = self.input[i .. i + 4];
                        const codepoint = std.fmt.parseInt(u16, hex, 16) catch return Error.InvalidEscape;
                        try result.append(@intCast(codepoint));
                        i += 3;
                    },
                    else => return Error.InvalidEscape,
                }
                i += 1;
            }
        }

        return Value{ .StringOwned = try result.toOwnedSlice() };
    }

    inline fn parseNumber(self: *Parser) Error!Value {
        const start = self.pos;

        if (self.pos < self.input.len and self.input[self.pos] == '-') {
            self.pos += 1;
        }

        if (self.pos >= self.input.len or !isDigit(self.input[self.pos])) {
            return Error.InvalidNumber;
        }

        while (self.pos < self.input.len) {
            const c = self.input[self.pos];
            if (isDigit(c) or c == '.' or c == 'e' or c == 'E' or c == '+' or c == '-') {
                self.pos += 1;
            } else {
                break;
            }
        }

        const number_str = self.input[start..self.pos];
        return Value{ .Number = number_str };
    }

    fn parseArray(self: *Parser) Error!Value {
        if (self.input[self.pos] != '[') return Error.InvalidSyntax;
        self.pos += 1;

        var result = std.array_list.Managed(Value).init(self.allocator);
        errdefer result.deinit();

        self.skipWhitespaceAndComments();
        if (self.pos < self.input.len and self.input[self.pos] == ']') {
            self.pos += 1;
            return Value{ .Array = try result.toOwnedSlice() };
        }

        while (true) {
            try result.append(try self.parseValue());

            self.skipWhitespaceAndComments();
            if (self.pos >= self.input.len) {
                return Error.UnexpectedEnd;
            }

            if (self.input[self.pos] == ']') {
                self.pos += 1;
                return Value{ .Array = try result.toOwnedSlice() };
            } else if (self.input[self.pos] == ',') {
                self.pos += 1;
                self.skipWhitespaceAndComments();
                // Check for trailing comma
                if (self.options.allow_trailing_commas and self.pos < self.input.len and self.input[self.pos] == ']') {
                    self.pos += 1;
                    return Value{ .Array = try result.toOwnedSlice() };
                }
            } else {
                return Error.ExpectedCommaOrEnd;
            }
        }
    }

    fn parseObject(self: *Parser) Error!Value {
        if (self.input[self.pos] != '{') return Error.InvalidSyntax;
        self.pos += 1;

        var result = std.array_list.Managed(Pair).init(self.allocator);
        errdefer result.deinit();

        self.skipWhitespaceAndComments();
        if (self.pos < self.input.len and self.input[self.pos] == '}') {
            self.pos += 1;
            return Value{ .Object = try result.toOwnedSlice() };
        }

        while (true) {
            self.skipWhitespaceAndComments();
            if (self.pos >= self.input.len or self.input[self.pos] != '"') {
                return Error.InvalidSyntax;
            }

            const key_value = try self.parseString();
            const key = switch (key_value) {
                .String => |s| s,
                .StringOwned => |s| s,
                else => return Error.InvalidSyntax,
            };

            self.skipWhitespaceAndComments();
            if (self.pos >= self.input.len or self.input[self.pos] != ':') {
                return Error.ExpectedColon;
            }
            self.pos += 1;

            const val = try self.parseValue();

            try result.append(Pair{ .key = key, .value = val });

            self.skipWhitespaceAndComments();
            if (self.pos >= self.input.len) {
                return Error.UnexpectedEnd;
            }

            if (self.input[self.pos] == '}') {
                self.pos += 1;
                return Value{ .Object = try result.toOwnedSlice() };
            } else if (self.input[self.pos] == ',') {
                self.pos += 1;
                self.skipWhitespaceAndComments();
                // Check for trailing comma
                if (self.options.allow_trailing_commas and self.pos < self.input.len and self.input[self.pos] == '}') {
                    self.pos += 1;
                    return Value{ .Object = try result.toOwnedSlice() };
                }
            } else {
                return Error.ExpectedCommaOrEnd;
            }
        }
    }

    fn skipWhitespaceAndComments(self: *Parser) void {
        while (true) {
            const old_pos = self.pos;
            self.skipWhitespace();

            if (!self.options.allow_comments) break;

            self.skipComments();

            if (self.pos == old_pos) break;
        }
    }

    fn skipWhitespace(self: *Parser) void {
        while (self.pos < self.input.len) {
            const c = self.input[self.pos];
            if (std.ascii.isWhitespace(c)) {
                if (self.options.track_position and c == '\n') {
                    self.line += 1;
                    self.column = 1;
                } else if (self.options.track_position) {
                    self.column += 1;
                }
                self.pos += 1;
            } else if (self.options.allow_control_chars and c < 0x20) {
                if (self.options.track_position) {
                    self.column += 1;
                }
                self.pos += 1;
            } else {
                break;
            }
        }
    }

    fn skipComments(self: *Parser) void {
        if (!self.options.allow_comments) return;

        while (self.pos + 1 < self.input.len) {
            if (self.input[self.pos] == '/' and self.input[self.pos + 1] == '/') {
                // Line comment: skip until newline
                while (self.pos < self.input.len and self.input[self.pos] != '\n') {
                    self.pos += 1;
                }
                if (self.pos < self.input.len and self.input[self.pos] == '\n') {
                    if (self.options.track_position) {
                        self.line += 1;
                        self.column = 1;
                    }
                    self.pos += 1;
                }
            } else if (self.input[self.pos] == '/' and self.input[self.pos + 1] == '*') {
                // Block comment: skip until */
                self.pos += 2;
                while (self.pos + 1 < self.input.len) {
                    if (self.input[self.pos] == '\n' and self.options.track_position) {
                        self.line += 1;
                        self.column = 1;
                    }
                    if (self.input[self.pos] == '*' and self.input[self.pos + 1] == '/') {
                        self.pos += 2;
                        break;
                    }
                    self.pos += 1;
                }
            } else {
                break;
            }
        }
    }
};

fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}
