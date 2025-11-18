const std = @import("std");
/// Error set for zjson
pub const Error = error{
    UnexpectedEnd,
    InvalidSyntax,
    InvalidEscape,
    InvalidNumber,
    ExpectedColon,
    ExpectedCommaOrEnd,
    ExpectedValue,
    TrailingCharacters,
    OutOfMemory,
};

/// Minimal JSON value type for zero-copy parsing
pub const Value = union(enum) {
    Null,
    Bool: bool,
    Number: []const u8, // zero-copy, not parsed to float/int
    String: []const u8,
    Object: []const Pair,
    Array: []const Value,
};

pub const Pair = struct {
    key: []const u8,
    value: Value,
};

/// Parse a JSON string into a Value (uses allocator for dynamic allocation)
pub fn parse(input: []const u8, allocator: std.mem.Allocator) Error!Value {
    var parser = Parser{
        .input = input,
        .pos = 0,
        .allocator = allocator,
    };
    return parser.parseValue();
}

/// Free all allocated memory for a parsed Value
/// Must be called once per Value returned from parse()
pub fn freeValue(value: Value, allocator: std.mem.Allocator) void {
    switch (value) {
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

/// Parser state machine for runtime JSON parsing
const Parser = struct {
    input: []const u8,
    pos: usize,
    allocator: std.mem.Allocator,

    fn parseValue(self: *Parser) Error!Value {
        self.skipWhitespace();
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

        // Optional minus
        if (self.pos < self.input.len and self.input[self.pos] == '-') {
            self.pos += 1;
        }

        // At least one digit
        if (self.pos >= self.input.len or !isDigit(self.input[self.pos])) {
            return Error.InvalidNumber;
        }

        // Consume digits (including optional decimal and exponent)
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
        if (self.pos < self.input.len and self.input[self.pos] == ']') {
            self.pos += 1;
            return Value{ .Array = try result.toOwnedSlice() };
        }

        while (true) {
            try result.append(try self.parseValue());

            self.skipWhitespace();
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
        if (self.pos < self.input.len and self.input[self.pos] == '}') {
            self.pos += 1;
            return Value{ .Object = try result.toOwnedSlice() };
        }

        while (true) {
            self.skipWhitespace();
            if (self.pos >= self.input.len or self.input[self.pos] != '"') {
                result.deinit();
                return Error.InvalidSyntax;
            }

            const key_value = try self.parseString();
            const key = key_value.String;

            self.skipWhitespace();
            if (self.pos >= self.input.len or self.input[self.pos] != ':') {
                result.deinit();
                return Error.ExpectedColon;
            }
            self.pos += 1;

            const value = try self.parseValue();

            try result.append(Pair{ .key = key, .value = value });

            self.skipWhitespace();
            if (self.pos >= self.input.len) {
                result.deinit();
                return Error.UnexpectedEnd;
            }

            if (self.input[self.pos] == '}') {
                self.pos += 1;
                return Value{ .Object = try result.toOwnedSlice() };
            } else if (self.input[self.pos] == ',') {
                self.pos += 1;
            } else {
                result.deinit();
                return Error.ExpectedCommaOrEnd;
            }
        }
    }

    fn skipWhitespace(self: *Parser) void {
        while (self.pos < self.input.len and std.ascii.isWhitespace(self.input[self.pos])) {
            self.pos += 1;
        }
    }
};

fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}

/// Compile-time JSON serialization for Zig structs
pub fn stringify(comptime value: anytype) []const u8 {
    return comptime _stringifyHelper(value);
}

fn _stringifyHelper(comptime value: anytype) []const u8 {
    const T = @TypeOf(value);
    if (T == bool) {
        return if (value) "true" else "false";
    } else if (T == void or T == @TypeOf(null)) {
        return "null";
    } else if (T == []const u8) {
        return _escape_string(value);
    } else if (@typeInfo(T) == .pointer) {
        const ptr_info = @typeInfo(T).pointer;
        if (ptr_info.child == u8 or (@typeInfo(ptr_info.child) == .array and @typeInfo(ptr_info.child).array.child == u8)) {
            // Handle string literals and slices
            const str: []const u8 = value;
            return _escape_string(str);
        } else if (ptr_info.size == .slice) {
            // Handle slices
            return _stringifyArray(value);
        } else if (@typeInfo(ptr_info.child) == .array) {
            // Handle pointers to arrays
            return _stringifyArray(value);
        } else {
            @compileError("zjson: unsupported pointer type for stringify: " ++ @typeName(T));
        }
    } else if (T == comptime_int or T == u8 or T == u16 or T == u32 or T == u64 or T == i8 or T == i16 or T == i32 or T == i64 or T == f16 or T == f32 or T == f64) {
        return std.fmt.comptimePrint("{}", .{value});
    } else if (@typeInfo(T) == .@"enum") {
        return _escape_string(@tagName(value));
    } else if (@typeInfo(T) == .optional) {
        if (value) |inner| {
            return _stringifyHelper(inner);
        } else {
            return "null";
        }
    } else if (@typeInfo(T) == .@"struct") {
        return _stringifyStruct(value);
    } else if (@typeInfo(T) == .array or @typeInfo(T) == .vector) {
        return _stringifyArray(value);
    } else {
        @compileError("zjson: unsupported type for stringify: " ++ @typeName(T));
    }
}

fn _stringifyStruct(comptime value: anytype) []const u8 {
    const T = @TypeOf(value);
    const fields = @typeInfo(T).@"struct".fields;

    comptime var result: []const u8 = "{";
    comptime var first = true;

    inline for (fields) |field| {
        const field_value = @field(value, field.name);

        // omitempty: skip null optionals
        if (@typeInfo(field.type) == .optional and field_value == null) {
            continue;
        }

        if (first) {
            first = false;
            result = result ++ _escape_string(field.name) ++ ":" ++ _stringifyHelper(field_value);
        } else {
            result = result ++ "," ++ _escape_string(field.name) ++ ":" ++ _stringifyHelper(field_value);
        }
    }
    result = result ++ "}";
    return result;
}

fn _stringifyArray(comptime value: anytype) []const u8 {
    comptime var result: []const u8 = "[";
    comptime var first = true;

    inline for (value) |item| {
        if (first) {
            first = false;
            result = result ++ _stringifyHelper(item);
        } else {
            result = result ++ "," ++ _stringifyHelper(item);
        }
    }
    result = result ++ "]";
    return result;
}

fn _escape_string(s: []const u8) []const u8 {
    comptime var result: []const u8 = "\"";
    inline for (s) |c| {
        switch (c) {
            '"' => result = result ++ "\\\"",
            '\\' => result = result ++ "\\\\",
            '\n' => result = result ++ "\\n",
            '\r' => result = result ++ "\\r",
            '\t' => result = result ++ "\\t",
            '\x08' => result = result ++ "\\b",
            '\x0C' => result = result ++ "\\f",
            '/' => result = result ++ "\\/",
            else => {
                if (c < 0x20) {
                    result = result ++ std.fmt.comptimePrint("\\u{X:0>4}", .{c});
                } else {
                    result = result ++ [_]u8{c};
                }
            },
        }
    }
    result = result ++ "\"";
    return result;
}
