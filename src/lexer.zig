const std = @import("std");
const value_mod = @import("value.zig");

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
    /// True if data was allocated and needs to be freed by caller
    allocated: bool,
    /// True if data is borrowed from input (safe only if input outlives usage)
    borrowed: bool,
};

/// Input source abstraction - either in-memory slice or buffered reader
pub fn Input(comptime ReaderType: type) type {
    return union(enum) {
        slice: SliceInput,
        buffered: BufferedInput,

        const Self = @This();

        pub const SliceInput = struct {
            data: []const u8,
            pos: usize = 0,
        };

        pub const BufferedInput = struct {
            buffer: std.ArrayList(u8),
            pos: usize = 0,
            reader: ReaderType,

            /// Ensure buffer has at least min_size bytes available from pos
            pub fn ensureBuffer(self: *BufferedInput, allocator: std.mem.Allocator, min_size: usize) !void {
                // For slice-only lexers (ReaderType == void), this is a no-op
                if (comptime ReaderType == void) {
                    return;
                }

                while (self.buffer.items.len - self.pos < min_size) {
                    var buf: [4096]u8 = undefined;
                    const n = try self.reader.read(&buf);
                    if (n == 0) break;
                    try self.buffer.appendSlice(allocator, buf[0..n]);
                }
            }
        };

        /// Peek at current character without advancing
        pub inline fn peek(self: *Self, allocator: std.mem.Allocator) !?u8 {
            return switch (self.*) {
                .slice => |*s| if (s.pos < s.data.len) s.data[s.pos] else null,
                .buffered => |*b| blk: {
                    try b.ensureBuffer(allocator, 1);
                    break :blk if (b.pos < b.buffer.items.len) b.buffer.items[b.pos] else null;
                },
            };
        }

        /// Advance position by count characters
        pub inline fn advance(self: *Self, pos: *Position, count: usize) void {
            var i: usize = 0;
            while (i < count) : (i += 1) {
                const c = switch (self.*) {
                    .slice => |*s| blk: {
                        if (s.pos >= s.data.len) break;
                        const ch = s.data[s.pos];
                        s.pos += 1;
                        break :blk ch;
                    },
                    .buffered => |*b| blk: {
                        if (b.pos >= b.buffer.items.len) break;
                        const ch = b.buffer.items[b.pos];
                        b.pos += 1;
                        break :blk ch;
                    },
                };

                if (c == '\n') {
                    pos.line += 1;
                    pos.column = 1;
                } else {
                    pos.column += 1;
                }
                pos.byte_offset += 1;
            }
        }

        /// Get current position in input
        pub inline fn currentPos(self: *const Self) usize {
            return switch (self.*) {
                .slice => |*s| s.pos,
                .buffered => |*b| b.pos,
            };
        }

        /// Get slice from start to current position (slice input only)
        pub inline fn getSlice(self: *const Self, start: usize) []const u8 {
            return switch (self.*) {
                .slice => |*s| s.data[start..s.pos],
                .buffered => |*b| b.buffer.items[start..b.pos],
            };
        }

        /// Get character at current position (buffered input only)
        pub inline fn charAt(self: *const Self, index: usize) u8 {
            return switch (self.*) {
                .slice => |*s| s.data[index],
                .buffered => |*b| b.buffer.items[index],
            };
        }

        /// Ensure buffered input has at least min_size bytes available
        pub inline fn ensureBuffer(self: *Self, allocator: std.mem.Allocator, min_size: usize) !void {
            switch (self.*) {
                .slice => {}, // No-op for slice
                .buffered => |*b| try b.ensureBuffer(allocator, min_size),
            }
        }

        /// Check if there's more input available
        pub inline fn hasMore(self: *Self, allocator: std.mem.Allocator) !bool {
            return switch (self.*) {
                .slice => |*s| s.pos < s.data.len,
                .buffered => |*b| blk: {
                    try b.ensureBuffer(allocator, 1);
                    break :blk b.pos < b.buffer.items.len;
                },
            };
        }
    };
}

/// Generic JSON lexer that works with both slice and buffered inputs
pub fn Lexer(comptime ReaderType: type) type {
    return struct {
        input: Input(ReaderType),
        position: Position,
        allocator: std.mem.Allocator,

        const Self = @This();

        /// Create lexer from in-memory slice
        pub fn initSlice(data: []const u8, allocator: std.mem.Allocator) Self {
            return .{
                .input = .{ .slice = .{ .data = data, .pos = 0 } },
                .position = .{},
                .allocator = allocator,
            };
        }

        /// Create lexer from buffered reader
        pub fn initBuffered(reader: ReaderType, allocator: std.mem.Allocator) Self {
            return .{
                .input = .{ .buffered = .{
                    .buffer = std.ArrayList(u8){},
                    .pos = 0,
                    .reader = reader,
                } },
                .position = .{},
                .allocator = allocator,
            };
        }

        /// Clean up resources
        pub fn deinit(self: *Self) void {
            switch (self.input) {
                .slice => {},
                .buffered => |*b| b.buffer.deinit(self.allocator),
            }
        }

        /// Skip whitespace characters
        pub fn skipWhitespace(self: *Self) !void {
            while (try self.input.hasMore(self.allocator)) {
                const c = (try self.input.peek(self.allocator)) orelse break;
                if (c == ' ' or c == '\t' or c == '\n' or c == '\r') {
                    self.input.advance(&self.position, 1);
                } else {
                    break;
                }
            }
        }

        /// Expect a specific literal sequence
        pub fn expectLiteral(self: *Self, expected: []const u8) !void {
            try self.input.ensureBuffer(self.allocator, expected.len);
            const start = self.input.currentPos();

            for (expected) |expected_char| {
                const c = (try self.input.peek(self.allocator)) orelse return Error.UnexpectedEnd;
                if (c != expected_char) return Error.InvalidSyntax;
                self.input.advance(&self.position, 1);
            }

            // Verify we matched the full sequence
            const end = self.input.currentPos();
            if (end - start != expected.len) return Error.InvalidSyntax;
        }

        /// Parse a JSON string value
        pub fn parseString(self: *Self) !StringResult {
            const c = (try self.input.peek(self.allocator)) orelse return Error.UnexpectedEnd;
            if (c != '"') return Error.InvalidSyntax;
            self.input.advance(&self.position, 1);

            const start = self.input.currentPos();
            var has_escape = false;

            // Fast scan to find end quote and check for escapes
            while (true) {
                try self.input.ensureBuffer(self.allocator, 1);
                const ch = (try self.input.peek(self.allocator)) orelse return Error.UnexpectedEnd;

                if (ch == '"') {
                    const end = self.input.currentPos();
                    self.input.advance(&self.position, 1);

                    if (has_escape) {
                        // Need to unescape - always allocates
                        const escaped = self.input.getSlice(start);
                        const unescaped = try self.unescapeString(escaped[0 .. end - start]);
                        return StringResult{ .data = unescaped, .allocated = true, .borrowed = false };
                    } else {
                        // No escapes - can we borrow?
                        const raw = self.input.getSlice(start);
                        return switch (self.input) {
                            .slice => StringResult{
                                .data = raw[0 .. end - start],
                                .allocated = false,
                                .borrowed = true,
                            },
                            .buffered => StringResult{
                                // Must duplicate - buffer may be reused
                                .data = try self.allocator.dupe(u8, raw[0 .. end - start]),
                                .allocated = true,
                                .borrowed = false,
                            },
                        };
                    }
                } else if (ch == '\\') {
                    has_escape = true;
                    self.input.advance(&self.position, 1);
                    try self.input.ensureBuffer(self.allocator, 1);
                    const escape_char = (try self.input.peek(self.allocator)) orelse return Error.UnexpectedEnd;
                    if (escape_char == 'u') {
                        self.input.advance(&self.position, 5); // Skip u + 4 hex digits
                    } else {
                        self.input.advance(&self.position, 1);
                    }
                } else if (ch < 0x20) {
                    return Error.InvalidSyntax;
                } else {
                    self.input.advance(&self.position, 1);
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

                            // Check for high surrogate (0xD800-0xDBFF)
                            if (codepoint >= 0xD800 and codepoint <= 0xDBFF) {
                                // Parse low surrogate
                                i += 4;
                                if (i + 5 >= escaped.len or escaped[i] != '\\' or escaped[i + 1] != 'u') {
                                    return Error.InvalidEscape;
                                }
                                i += 2;
                                if (i + 3 >= escaped.len) return Error.InvalidEscape;
                                const low_hex = escaped[i..][0..4];
                                const low_codepoint = std.fmt.parseInt(u16, low_hex, 16) catch return Error.InvalidEscape;

                                // Verify valid low surrogate (0xDC00-0xDFFF)
                                if (low_codepoint < 0xDC00 or low_codepoint > 0xDFFF) {
                                    return Error.InvalidEscape;
                                }

                                // Combine surrogates into full codepoint
                                const full_codepoint: u21 = 0x10000 + ((@as(u21, codepoint) - 0xD800) << 10) + (@as(u21, low_codepoint) - 0xDC00);

                                // Encode as UTF-8
                                var utf8_buf: [4]u8 = undefined;
                                const utf8_len = std.unicode.utf8Encode(full_codepoint, &utf8_buf) catch return Error.InvalidEscape;
                                try result.appendSlice(self.allocator, utf8_buf[0..utf8_len]);
                                i += 3;
                            } else if (codepoint >= 0xDC00 and codepoint <= 0xDFFF) {
                                // Lone low surrogate - invalid
                                return Error.InvalidEscape;
                            } else {
                                // Regular codepoint - encode as UTF-8
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

            try self.input.ensureBuffer(self.allocator, 1);
            var c = (try self.input.peek(self.allocator)) orelse return Error.InvalidNumber;

            // Optional minus sign
            if (c == '-') {
                self.input.advance(&self.position, 1);
                try self.input.ensureBuffer(self.allocator, 1);
                c = (try self.input.peek(self.allocator)) orelse return Error.InvalidNumber;
            }

            // Integer part
            if (!std.ascii.isDigit(c)) return Error.InvalidNumber;

            if (c == '0') {
                self.input.advance(&self.position, 1);
            } else {
                // 1-9 followed by digits
                while (try self.input.hasMore(self.allocator)) {
                    c = (try self.input.peek(self.allocator)) orelse break;
                    if (!std.ascii.isDigit(c)) break;
                    self.input.advance(&self.position, 1);
                }
            }

            // Optional fractional part
            if (try self.input.hasMore(self.allocator)) {
                c = (try self.input.peek(self.allocator)) orelse {
                    const num_slice = self.input.getSlice(start);
                    return try self.allocator.dupe(u8, num_slice);
                };
                if (c == '.') {
                    self.input.advance(&self.position, 1);
                    try self.input.ensureBuffer(self.allocator, 1);
                    c = (try self.input.peek(self.allocator)) orelse return Error.InvalidNumber;
                    if (!std.ascii.isDigit(c)) return Error.InvalidNumber;

                    while (try self.input.hasMore(self.allocator)) {
                        c = (try self.input.peek(self.allocator)) orelse break;
                        if (!std.ascii.isDigit(c)) break;
                        self.input.advance(&self.position, 1);
                    }
                }
            }

            // Optional exponent part
            if (try self.input.hasMore(self.allocator)) {
                c = (try self.input.peek(self.allocator)) orelse {
                    const num_slice = self.input.getSlice(start);
                    return try self.allocator.dupe(u8, num_slice);
                };
                if (c == 'e' or c == 'E') {
                    self.input.advance(&self.position, 1);
                    if (try self.input.hasMore(self.allocator)) {
                        c = (try self.input.peek(self.allocator)) orelse return Error.InvalidNumber;
                        if (c == '+' or c == '-') {
                            self.input.advance(&self.position, 1);
                        }
                    }

                    try self.input.ensureBuffer(self.allocator, 1);
                    c = (try self.input.peek(self.allocator)) orelse return Error.InvalidNumber;
                    if (!std.ascii.isDigit(c)) return Error.InvalidNumber;

                    while (try self.input.hasMore(self.allocator)) {
                        c = (try self.input.peek(self.allocator)) orelse break;
                        if (!std.ascii.isDigit(c)) break;
                        self.input.advance(&self.position, 1);
                    }
                }
            }

            const num_slice = self.input.getSlice(start);
            return try self.allocator.dupe(u8, num_slice);
        }
    };
}
