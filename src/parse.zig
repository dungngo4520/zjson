const std = @import("std");
const value_mod = @import("value.zig");

pub const Error = value_mod.Error;
pub const Value = value_mod.Value;
pub const Pair = value_mod.Pair;
pub const ParseOptions = value_mod.ParseOptions;

pub fn parse(input: []const u8, allocator: std.mem.Allocator, options: ParseOptions) Error!Value {
    var parser = Parser{
        .input = input,
        .pos = 0,
        .allocator = allocator,
        .options = options,
    };
    const result = try parser.parseValue();

    // Check for trailing characters if not explicitly allowed
    parser.skipWhitespace();
    if (parser.pos < parser.input.len) {
        // Free allocated memory before returning error
        freeValue(result, allocator);
        return Error.TrailingCharacters;
    }

    return result;
}

pub fn freeValue(val: Value, allocator: std.mem.Allocator) void {
    switch (val) {
        .String => |s| allocator.free(s),
        .Number => |n| allocator.free(n),
        .Array => |arr| {
            for (arr) |item| {
                freeValue(item, allocator);
            }
            allocator.free(arr);
        },
        .Object => |obj| {
            for (obj) |pair| {
                freeValue(pair.value, allocator);
                allocator.free(pair.key);
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

    fn parseValue(self: *Parser) Error!Value {
        self.skipWhitespace();
        if (self.options.allow_comments) {
            self.skipComments();
            self.skipWhitespace();
        }
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

    fn parseNull(self: *Parser) Error!Value {
        if (self.pos + 4 > self.input.len or !std.mem.eql(u8, self.input[self.pos .. self.pos + 4], "null")) {
            return Error.InvalidSyntax;
        }
        self.pos += 4;
        return Value.Null;
    }

    fn parseBool(self: *Parser) Error!Value {
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

        var result = std.array_list.Managed(u8).init(self.allocator);

        while (self.pos < self.input.len) {
            const c = self.input[self.pos];
            switch (c) {
                '"' => {
                    self.pos += 1;
                    return Value{ .String = try result.toOwnedSlice() };
                },
                '\\' => {
                    self.pos += 1;
                    if (self.pos >= self.input.len) return Error.UnexpectedEnd;
                    switch (self.input[self.pos]) {
                        '"' => try result.append('"'),
                        '\\' => try result.append('\\'),
                        '/' => try result.append('/'),
                        'b' => try result.append('\x08'),
                        'f' => try result.append('\x0C'),
                        'n' => try result.append('\n'),
                        'r' => try result.append('\r'),
                        't' => try result.append('\t'),
                        'u' => {
                            self.pos += 1;
                            if (self.pos + 3 >= self.input.len) return Error.InvalidEscape;
                            const hex = self.input[self.pos .. self.pos + 4];
                            const codepoint = std.fmt.parseInt(u16, hex, 16) catch return Error.InvalidEscape;
                            try result.append(@intCast(codepoint));
                            self.pos += 3;
                        },
                        else => return Error.InvalidEscape,
                    }
                    self.pos += 1;
                },
                else => {
                    try result.append(c);
                    self.pos += 1;
                },
            }
        }
        result.deinit();
        return Error.UnexpectedEnd;
    }

    fn parseNumber(self: *Parser) Error!Value {
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
        const result = try self.allocator.dupe(u8, number_str);
        return Value{ .Number = result };
    }

    fn parseArray(self: *Parser) Error!Value {
        if (self.input[self.pos] != '[') return Error.InvalidSyntax;
        self.pos += 1;

        var result = std.array_list.Managed(Value).init(self.allocator);

        self.skipWhitespace();
        if (self.options.allow_comments) {
            self.skipComments();
            self.skipWhitespace();
        }
        if (self.pos < self.input.len and self.input[self.pos] == ']') {
            self.pos += 1;
            return Value{ .Array = try result.toOwnedSlice() };
        }

        while (true) {
            try result.append(try self.parseValue());

            self.skipWhitespace();
            if (self.options.allow_comments) {
                self.skipComments();
                self.skipWhitespace();
            }
            if (self.pos >= self.input.len) {
                result.deinit();
                return Error.UnexpectedEnd;
            }

            if (self.input[self.pos] == ']') {
                self.pos += 1;
                return Value{ .Array = try result.toOwnedSlice() };
            } else if (self.input[self.pos] == ',') {
                self.pos += 1;
                self.skipWhitespace();
                if (self.options.allow_comments) {
                    self.skipComments();
                    self.skipWhitespace();
                }
                // Check for trailing comma
                if (self.options.allow_trailing_commas and self.pos < self.input.len and self.input[self.pos] == ']') {
                    self.pos += 1;
                    return Value{ .Array = try result.toOwnedSlice() };
                }
            } else {
                result.deinit();
                return Error.ExpectedCommaOrEnd;
            }
        }
    }

    fn parseObject(self: *Parser) Error!Value {
        if (self.input[self.pos] != '{') return Error.InvalidSyntax;
        self.pos += 1;

        var result = std.array_list.Managed(Pair).init(self.allocator);

        self.skipWhitespace();
        if (self.options.allow_comments) {
            self.skipComments();
            self.skipWhitespace();
        }
        if (self.pos < self.input.len and self.input[self.pos] == '}') {
            self.pos += 1;
            return Value{ .Object = try result.toOwnedSlice() };
        }

        while (true) {
            self.skipWhitespace();
            if (self.options.allow_comments) {
                self.skipComments();
                self.skipWhitespace();
            }
            if (self.pos >= self.input.len or self.input[self.pos] != '"') {
                result.deinit();
                return Error.InvalidSyntax;
            }

            const key_value = try self.parseString();
            const key = key_value.String;

            self.skipWhitespace();
            if (self.options.allow_comments) {
                self.skipComments();
                self.skipWhitespace();
            }
            if (self.pos >= self.input.len or self.input[self.pos] != ':') {
                result.deinit();
                return Error.ExpectedColon;
            }
            self.pos += 1;

            const val = try self.parseValue();

            try result.append(Pair{ .key = key, .value = val });

            self.skipWhitespace();
            if (self.options.allow_comments) {
                self.skipComments();
                self.skipWhitespace();
            }
            if (self.pos >= self.input.len) {
                result.deinit();
                return Error.UnexpectedEnd;
            }

            if (self.input[self.pos] == '}') {
                self.pos += 1;
                return Value{ .Object = try result.toOwnedSlice() };
            } else if (self.input[self.pos] == ',') {
                self.pos += 1;
                self.skipWhitespace();
                if (self.options.allow_comments) {
                    self.skipComments();
                    self.skipWhitespace();
                }
                // Check for trailing comma
                if (self.options.allow_trailing_commas and self.pos < self.input.len and self.input[self.pos] == '}') {
                    self.pos += 1;
                    return Value{ .Object = try result.toOwnedSlice() };
                }
            } else {
                result.deinit();
                return Error.ExpectedCommaOrEnd;
            }
        }
    }

    fn skipWhitespace(self: *Parser) void {
        while (self.pos < self.input.len) {
            const c = self.input[self.pos];
            if (std.ascii.isWhitespace(c)) {
                self.pos += 1;
            } else if (self.options.allow_control_chars and c < 0x20) {
                // Allow control characters if option is enabled
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
                    self.pos += 1;
                }
                self.skipWhitespace();
            } else if (self.input[self.pos] == '/' and self.input[self.pos + 1] == '*') {
                // Block comment: skip until */
                self.pos += 2;
                while (self.pos + 1 < self.input.len) {
                    if (self.input[self.pos] == '*' and self.input[self.pos + 1] == '/') {
                        self.pos += 2;
                        break;
                    }
                    self.pos += 1;
                }
                self.skipWhitespace();
            } else {
                break;
            }
        }
    }
};

fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}
