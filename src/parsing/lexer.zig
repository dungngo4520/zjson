const std = @import("std");
const value_mod = @import("../core/value.zig");

pub const Error = value_mod.Error;

/// Position tracking in the input
pub const Position = struct {
    line: usize = 1,
    column: usize = 1,
    byte_offset: usize = 0,
};

/// Result of parsing a string with allocation information
pub const StringResult = struct {
    data: []const u8,
    allocated: bool,
    borrowed: bool,
};

/// Slice-based input reader (zero-allocation for borrowing strings)
pub const SliceInput = struct {
    data: []const u8,
    pos: usize = 0,

    pub fn init(data: []const u8) SliceInput {
        return .{ .data = data, .pos = 0 };
    }

    pub inline fn peek(self: *SliceInput) ?u8 {
        return if (self.pos < self.data.len) self.data[self.pos] else null;
    }

    pub inline fn advance(self: *SliceInput) void {
        if (self.pos < self.data.len) self.pos += 1;
    }

    pub inline fn currentPos(self: *const SliceInput) usize {
        return self.pos;
    }

    pub inline fn getSlice(self: *const SliceInput, start: usize) []const u8 {
        return self.data[start..self.pos];
    }

    pub inline fn charAt(self: *const SliceInput, index: usize) u8 {
        return self.data[index];
    }

    pub inline fn hasMore(self: *SliceInput) bool {
        return self.pos < self.data.len;
    }

    pub fn deinit(self: *SliceInput, allocator: std.mem.Allocator) void {
        _ = self;
        _ = allocator;
    }
};

/// Buffered input reader (for streaming from files/sockets)
pub fn BufferedInput(comptime ReaderType: type) type {
    return struct {
        buffer: std.ArrayList(u8),
        pos: usize = 0,
        reader: ReaderType,
        at_eof: bool = false,

        const Self = @This();

        pub fn init(reader: ReaderType) Self {
            return .{
                .buffer = std.ArrayList(u8){},
                .pos = 0,
                .reader = reader,
                .at_eof = false,
            };
        }

        pub fn ensureBuffer(self: *Self, allocator: std.mem.Allocator, min_size: usize) !void {
            if (self.at_eof) return;

            while (self.buffer.items.len - self.pos < min_size) {
                var buf: [4096]u8 = undefined;
                const n = try self.reader.read(&buf);
                if (n == 0) {
                    self.at_eof = true;
                    return;
                }
                try self.buffer.appendSlice(allocator, buf[0..n]);
            }
        }

        pub inline fn peek(self: *Self) ?u8 {
            return if (self.pos < self.buffer.items.len) self.buffer.items[self.pos] else null;
        }

        pub inline fn advance(self: *Self) void {
            if (self.pos < self.buffer.items.len) self.pos += 1;
        }

        pub inline fn currentPos(self: *const Self) usize {
            return self.pos;
        }

        pub inline fn getSlice(self: *const Self, start: usize) []const u8 {
            return self.buffer.items[start..self.pos];
        }

        pub inline fn charAt(self: *const Self, index: usize) u8 {
            return self.buffer.items[index];
        }

        pub fn hasMore(self: *Self, allocator: std.mem.Allocator) !bool {
            try self.ensureBuffer(allocator, 1);
            return self.pos < self.buffer.items.len;
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            self.buffer.deinit(allocator);
        }
    };
}

/// Generic lexer core that works with both slice and buffered inputs
/// InputType must have: peek(), advance(), currentPos(), getSlice(), hasMore(), deinit()
pub fn LexerCore(comptime InputType: type) type {
    return struct {
        input: InputType,
        position: Position,
        allocator: std.mem.Allocator,

        const Self = @This();

        pub fn init(input: InputType, allocator: std.mem.Allocator) Self {
            return .{
                .input = input,
                .position = .{},
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.input.deinit(self.allocator);
        }

        /// Advance position by one character, tracking line/column
        inline fn advancePos(self: *Self) void {
            if (self.input.peek()) |c| {
                self.input.advance();
                if (c == '\n') {
                    self.position.line += 1;
                    self.position.column = 1;
                } else {
                    self.position.column += 1;
                }
                self.position.byte_offset += 1;
            }
        }

        /// Skip whitespace characters
        pub fn skipWhitespace(self: *Self) !void {
            while (true) {
                const c = self.input.peek() orelse break;
                if (c == ' ' or c == '\t' or c == '\n' or c == '\r') {
                    self.advancePos();
                } else {
                    break;
                }
            }
        }

        /// Expect a specific literal sequence
        pub fn expectLiteral(self: *Self, expected: []const u8) !void {
            for (expected) |expected_char| {
                const c = self.input.peek() orelse return Error.UnexpectedEnd;
                if (c != expected_char) return Error.InvalidSyntax;
                self.advancePos();
            }
        }

        /// Parse a JSON string value
        pub fn parseString(self: *Self) !StringResult {
            if (InputType != SliceInput) try self.input.ensureBuffer(self.allocator, 1);
            const c = self.input.peek() orelse return Error.UnexpectedEnd;
            if (c != '"') return Error.InvalidSyntax;
            self.advancePos();

            const start = self.input.currentPos();
            var has_escape = false;

            while (true) {
                if (InputType != SliceInput) try self.input.ensureBuffer(self.allocator, 1);
                const ch = self.input.peek() orelse return Error.UnexpectedEnd;

                if (ch == '"') {
                    const end = self.input.currentPos();
                    self.advancePos();

                    if (has_escape) {
                        const escaped = self.input.getSlice(start);
                        const unescaped = try self.unescapeString(escaped[0 .. end - start]);
                        return StringResult{ .data = unescaped, .allocated = true, .borrowed = false };
                    } else {
                        const raw = self.input.getSlice(start);
                        if (InputType == SliceInput) {
                            return StringResult{
                                .data = raw[0 .. end - start],
                                .allocated = false,
                                .borrowed = true,
                            };
                        } else {
                            return StringResult{
                                .data = try self.allocator.dupe(u8, raw[0 .. end - start]),
                                .allocated = true,
                                .borrowed = false,
                            };
                        }
                    }
                } else if (ch == '\\') {
                    has_escape = true;
                    self.advancePos();
                    if (InputType != SliceInput) try self.input.ensureBuffer(self.allocator, 1);
                    const escape_char = self.input.peek() orelse return Error.UnexpectedEnd;
                    if (escape_char == 'u') {
                        self.advancePos();
                        var i: usize = 0;
                        while (i < 4) : (i += 1) {
                            if (InputType != SliceInput) try self.input.ensureBuffer(self.allocator, 1);
                            self.advancePos();
                        }
                    } else {
                        self.advancePos();
                    }
                } else if (ch < 0x20) {
                    return Error.InvalidSyntax;
                } else {
                    self.advancePos();
                }
            }
        }

        /// Unescape a JSON string (handles \", \\, \n, \uXXXX, surrogate pairs)
        fn unescapeString(self: *Self, escaped: []const u8) ![]const u8 {
            var result = try std.ArrayList(u8).initCapacity(self.allocator, escaped.len);
            errdefer result.deinit(self.allocator);

            var i: usize = 0;
            while (i < escaped.len) {
                if (escaped[i] == '\\') {
                    i += 1;
                    if (i >= escaped.len) return Error.InvalidEscape;

                    switch (escaped[i]) {
                        '"' => try result.append(self.allocator, '"'),
                        '\\' => try result.append(self.allocator, '\\'),
                        '/' => try result.append(self.allocator, '/'),
                        'b' => try result.append(self.allocator, '\x08'),
                        'f' => try result.append(self.allocator, '\x0C'),
                        'n' => try result.append(self.allocator, '\n'),
                        'r' => try result.append(self.allocator, '\r'),
                        't' => try result.append(self.allocator, '\t'),
                        'u' => {
                            i += 1;
                            if (i + 3 >= escaped.len) return Error.InvalidEscape;
                            const hex = escaped[i..][0..4];
                            const codepoint = std.fmt.parseInt(u16, hex, 16) catch return Error.InvalidEscape;

                            if (codepoint >= 0xD800 and codepoint <= 0xDBFF) {
                                i += 4;
                                if (i + 5 >= escaped.len or escaped[i] != '\\' or escaped[i + 1] != 'u') {
                                    return Error.InvalidEscape;
                                }
                                i += 2;
                                if (i + 3 >= escaped.len) return Error.InvalidEscape;
                                const low_hex = escaped[i..][0..4];
                                const low_codepoint = std.fmt.parseInt(u16, low_hex, 16) catch return Error.InvalidEscape;

                                if (low_codepoint < 0xDC00 or low_codepoint > 0xDFFF) {
                                    return Error.InvalidEscape;
                                }

                                const full_codepoint: u21 = 0x10000 + ((@as(u21, codepoint) - 0xD800) << 10) + (@as(u21, low_codepoint) - 0xDC00);

                                var utf8_buf: [4]u8 = undefined;
                                const utf8_len = std.unicode.utf8Encode(full_codepoint, &utf8_buf) catch return Error.InvalidEscape;
                                try result.appendSlice(self.allocator, utf8_buf[0..utf8_len]);
                                i += 3;
                            } else if (codepoint >= 0xDC00 and codepoint <= 0xDFFF) {
                                return Error.InvalidEscape;
                            } else {
                                var utf8_buf: [4]u8 = undefined;
                                const utf8_len = std.unicode.utf8Encode(codepoint, &utf8_buf) catch return Error.InvalidEscape;
                                try result.appendSlice(self.allocator, utf8_buf[0..utf8_len]);
                                i += 3;
                            }
                        },
                        else => return Error.InvalidEscape,
                    }
                    i += 1;
                } else {
                    try result.append(self.allocator, escaped[i]);
                    i += 1;
                }
            }

            return result.toOwnedSlice(self.allocator);
        }

        /// Parse a JSON number value (returns slice, not parsed)
        pub fn parseNumber(self: *Self) ![]const u8 {
            const start = self.input.currentPos();

            if (InputType == SliceInput) {
                // Slice input doesn't need ensureBuffer
            } else {
                try self.input.ensureBuffer(self.allocator, 1);
            }

            var c = self.input.peek() orelse return Error.InvalidNumber;

            if (c == '-') {
                self.advancePos();
                if (InputType != SliceInput) try self.input.ensureBuffer(self.allocator, 1);
                c = self.input.peek() orelse return Error.InvalidNumber;
            }

            if (!std.ascii.isDigit(c)) return Error.InvalidNumber;

            if (c == '0') {
                self.advancePos();
            } else {
                while (true) {
                    if (InputType != SliceInput) try self.input.ensureBuffer(self.allocator, 1);
                    c = self.input.peek() orelse break;
                    if (!std.ascii.isDigit(c)) break;
                    self.advancePos();
                }
            }

            if (self.input.peek()) |next_c| {
                if (next_c == '.') {
                    self.advancePos();
                    if (InputType != SliceInput) try self.input.ensureBuffer(self.allocator, 1);
                    c = self.input.peek() orelse return Error.InvalidNumber;
                    if (!std.ascii.isDigit(c)) return Error.InvalidNumber;

                    while (true) {
                        if (InputType != SliceInput) try self.input.ensureBuffer(self.allocator, 1);
                        c = self.input.peek() orelse break;
                        if (!std.ascii.isDigit(c)) break;
                        self.advancePos();
                    }
                }
            }

            if (self.input.peek()) |next_c| {
                if (next_c == 'e' or next_c == 'E') {
                    self.advancePos();
                    if (self.input.peek()) |sign_c| {
                        if (sign_c == '+' or sign_c == '-') {
                            self.advancePos();
                        }
                    }

                    if (InputType != SliceInput) try self.input.ensureBuffer(self.allocator, 1);
                    c = self.input.peek() orelse return Error.InvalidNumber;
                    if (!std.ascii.isDigit(c)) return Error.InvalidNumber;

                    while (true) {
                        if (InputType != SliceInput) try self.input.ensureBuffer(self.allocator, 1);
                        c = self.input.peek() orelse break;
                        if (!std.ascii.isDigit(c)) break;
                        self.advancePos();
                    }
                }
            }

            const num_slice = self.input.getSlice(start);
            return try self.allocator.dupe(u8, num_slice);
        }
    };
}

/// Slice-based lexer (zero-copy for borrowing strings)
pub const SliceLexer = LexerCore(SliceInput);

/// Buffered lexer for streaming readers
pub fn BufferedLexer(comptime ReaderType: type) type {
    return LexerCore(BufferedInput(ReaderType));
}
