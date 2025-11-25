const std = @import("std");
const zjson = @import("zjson");
const test_utils = @import("test_utils.zig");

// Test parseString with slice input
test "lexer: parse simple string (slice)" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            const input = "\"hello world\"";
            const slice_input = zjson.SliceInput.init(input);
            var lexer = zjson.SliceLexer.init(slice_input, allocator);

            const result = try lexer.parseString();
            defer if (result.allocated) allocator.free(result.data);

            try std.testing.expectEqualStrings("hello world", result.data);
            try std.testing.expect(!result.allocated); // Should be borrowed from slice
            try std.testing.expect(result.borrowed);
        }
    }.run);
}

// Test parseString with escape sequences
test "lexer: parse string with escapes (slice)" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            const input = "\"hello\\nworld\\t\\\"quoted\\\"\"";
            const slice_input = zjson.SliceInput.init(input);
            var lexer = zjson.SliceLexer.init(slice_input, allocator);

            const result = try lexer.parseString();
            defer if (result.allocated) allocator.free(result.data);

            try std.testing.expectEqualStrings("hello\nworld\t\"quoted\"", result.data);
            try std.testing.expect(result.allocated); // Must allocate for unescaping
            try std.testing.expect(!result.borrowed);
        }
    }.run);
}

// Test parseString with UTF-16 surrogate pair
test "lexer: parse string with surrogate pair (slice)" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            // UTF-16 surrogate pair for 😀 (U+1F600)
            // High: 0xD83D, Low: 0xDE00
            const input = "\"\\uD83D\\uDE00\"";
            const slice_input = zjson.SliceInput.init(input);
            var lexer = zjson.SliceLexer.init(slice_input, allocator);

            const result = try lexer.parseString();
            defer if (result.allocated) allocator.free(result.data);

            // Should decode to UTF-8: 😀
            try std.testing.expectEqualStrings("😀", result.data);
            try std.testing.expect(result.allocated);
        }
    }.run);
}

// Test parseString with invalid surrogate pair
test "lexer: parse string with invalid surrogate pair (slice)" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            // High surrogate without low surrogate
            const input = "\"\\uD83D\"";
            const slice_input = zjson.SliceInput.init(input);
            var lexer = zjson.SliceLexer.init(slice_input, allocator);

            const result = lexer.parseString();
            try std.testing.expectError(zjson.LexerError.InvalidEscape, result);
        }
    }.run);
}

// Test parseString with lone low surrogate
test "lexer: parse string with lone low surrogate (slice)" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            // Low surrogate without high surrogate
            const input = "\"\\uDE00\"";
            const slice_input = zjson.SliceInput.init(input);
            var lexer = zjson.SliceLexer.init(slice_input, allocator);

            const result = lexer.parseString();
            try std.testing.expectError(zjson.LexerError.InvalidEscape, result);
        }
    }.run);
}

// Test parseString with regular unicode escape
test "lexer: parse string with unicode escape (slice)" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            const input = "\"\\u0041\\u0042\\u0043\""; // ABC
            const slice_input = zjson.SliceInput.init(input);
            var lexer = zjson.SliceLexer.init(slice_input, allocator);

            const result = try lexer.parseString();
            defer if (result.allocated) allocator.free(result.data);

            try std.testing.expectEqualStrings("ABC", result.data);
            try std.testing.expect(result.allocated);
        }
    }.run);
}

// Test parseString with control characters (should fail)
test "lexer: parse string with control character (slice)" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            const input = "\"hello\x01world\""; // Control character
            const slice_input = zjson.SliceInput.init(input);
            var lexer = zjson.SliceLexer.init(slice_input, allocator);

            const result = lexer.parseString();
            try std.testing.expectError(zjson.LexerError.InvalidSyntax, result);
        }
    }.run);
}

// Test parseString with unterminated string
test "lexer: parse unterminated string (slice)" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            const input = "\"hello world";
            const slice_input = zjson.SliceInput.init(input);
            var lexer = zjson.SliceLexer.init(slice_input, allocator);

            const result = lexer.parseString();
            try std.testing.expectError(zjson.LexerError.UnexpectedEnd, result);
        }
    }.run);
}

// Test parseNumber with integer
test "lexer: parse integer (slice)" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            const input = "42";
            const slice_input = zjson.SliceInput.init(input);
            var lexer = zjson.SliceLexer.init(slice_input, allocator);

            const result = try lexer.parseNumber();
            defer allocator.free(result);

            try std.testing.expectEqualStrings("42", result);
        }
    }.run);
}

// Test parseNumber with negative integer
test "lexer: parse negative integer (slice)" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            const input = "-123";
            const slice_input = zjson.SliceInput.init(input);
            var lexer = zjson.SliceLexer.init(slice_input, allocator);

            const result = try lexer.parseNumber();
            defer allocator.free(result);

            try std.testing.expectEqualStrings("-123", result);
        }
    }.run);
}

// Test parseNumber with zero
test "lexer: parse zero (slice)" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            const input = "0";
            const slice_input = zjson.SliceInput.init(input);
            var lexer = zjson.SliceLexer.init(slice_input, allocator);

            const result = try lexer.parseNumber();
            defer allocator.free(result);

            try std.testing.expectEqualStrings("0", result);
        }
    }.run);
}

// Test parseNumber with float
test "lexer: parse float (slice)" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            const input = "3.14159";
            const slice_input = zjson.SliceInput.init(input);
            var lexer = zjson.SliceLexer.init(slice_input, allocator);

            const result = try lexer.parseNumber();
            defer allocator.free(result);

            try std.testing.expectEqualStrings("3.14159", result);
        }
    }.run);
}

// Test parseNumber with exponent
test "lexer: parse number with exponent (slice)" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            const input = "1.5e10";
            const slice_input = zjson.SliceInput.init(input);
            var lexer = zjson.SliceLexer.init(slice_input, allocator);

            const result = try lexer.parseNumber();
            defer allocator.free(result);

            try std.testing.expectEqualStrings("1.5e10", result);
        }
    }.run);
}

// Test parseNumber with negative exponent
test "lexer: parse number with negative exponent (slice)" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            const input = "2.5E-3";
            const slice_input = zjson.SliceInput.init(input);
            var lexer = zjson.SliceLexer.init(slice_input, allocator);

            const result = try lexer.parseNumber();
            defer allocator.free(result);

            try std.testing.expectEqualStrings("2.5E-3", result);
        }
    }.run);
}

// Test parseNumber with invalid number (leading zero)
test "lexer: parse invalid number with leading zero (slice)" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            const input = "01";
            const slice_input = zjson.SliceInput.init(input);
            var lexer = zjson.SliceLexer.init(slice_input, allocator);

            const num = try lexer.parseNumber();
            defer allocator.free(num);

            const has_more = lexer.input.hasMore();
            try std.testing.expect(has_more);
        }
    }.run);
}

// Test parseNumber with missing fractional part
test "lexer: parse number with invalid fractional (slice)" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            const input = "1.";
            const slice_input = zjson.SliceInput.init(input);
            var lexer = zjson.SliceLexer.init(slice_input, allocator);

            const result = lexer.parseNumber();
            try std.testing.expectError(zjson.LexerError.InvalidNumber, result);
        }
    }.run);
}

// Test skipWhitespace
test "lexer: skip whitespace (slice)" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            const input = "   \t\n\r  42";
            const slice_input = zjson.SliceInput.init(input);
            var lexer = zjson.SliceLexer.init(slice_input, allocator);

            try lexer.skipWhitespace();

            const c = lexer.input.peek();
            try std.testing.expectEqual(@as(u8, '4'), c.?);
        }
    }.run);
}

// Test expectLiteral for "null"
test "lexer: expect literal null (slice)" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            const input = "null";
            const slice_input = zjson.SliceInput.init(input);
            var lexer = zjson.SliceLexer.init(slice_input, allocator);

            try lexer.expectLiteral("null");

            const has_more = lexer.input.hasMore();
            try std.testing.expect(!has_more);
        }
    }.run);
}

// Test expectLiteral for "true"
test "lexer: expect literal true (slice)" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            const input = "true";
            const slice_input = zjson.SliceInput.init(input);
            var lexer = zjson.SliceLexer.init(slice_input, allocator);

            try lexer.expectLiteral("true");

            const has_more = lexer.input.hasMore();
            try std.testing.expect(!has_more);
        }
    }.run);
}

// Test expectLiteral for "false"
test "lexer: expect literal false (slice)" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            const input = "false";
            const slice_input = zjson.SliceInput.init(input);
            var lexer = zjson.SliceLexer.init(slice_input, allocator);

            try lexer.expectLiteral("false");

            const has_more = lexer.input.hasMore();
            try std.testing.expect(!has_more);
        }
    }.run);
}

// Test expectLiteral with wrong input
test "lexer: expect literal mismatch (slice)" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            const input = "nope";
            const slice_input = zjson.SliceInput.init(input);
            var lexer = zjson.SliceLexer.init(slice_input, allocator);

            const result = lexer.expectLiteral("null");
            try std.testing.expectError(zjson.LexerError.InvalidSyntax, result);
        }
    }.run);
}

// Test position tracking
test "lexer: position tracking (slice)" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            const input = "hello\nworld";
            const slice_input = zjson.SliceInput.init(input);
            var lexer = zjson.SliceLexer.init(slice_input, allocator);

            try std.testing.expectEqual(@as(usize, 1), lexer.position.line);
            try std.testing.expectEqual(@as(usize, 1), lexer.position.column);
            try std.testing.expectEqual(@as(usize, 0), lexer.position.byte_offset);

            var i: usize = 0;
            while (i < 6) : (i += 1) {
                if (lexer.input.peek()) |c| {
                    lexer.input.advance();
                    if (c == '\n') {
                        lexer.position.line += 1;
                        lexer.position.column = 1;
                    } else {
                        lexer.position.column += 1;
                    }
                    lexer.position.byte_offset += 1;
                }
            }

            try std.testing.expectEqual(@as(usize, 2), lexer.position.line);
            try std.testing.expectEqual(@as(usize, 1), lexer.position.column);
            try std.testing.expectEqual(@as(usize, 6), lexer.position.byte_offset);
        }
    }.run);
}

// Test buffered input with parseString
test "lexer: parse string with buffered input" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            const input = "\"hello world\"";
            var fbs = std.io.fixedBufferStream(input);
            const buffered_input = zjson.BufferedInput(@TypeOf(fbs.reader())).init(fbs.reader());
            var lexer = zjson.BufferedLexer(@TypeOf(fbs.reader())).init(buffered_input, allocator);
            defer lexer.deinit();

            const result = try lexer.parseString();
            defer if (result.allocated) allocator.free(result.data);

            try std.testing.expectEqualStrings("hello world", result.data);
            try std.testing.expect(result.allocated); // Buffered input must allocate
            try std.testing.expect(!result.borrowed);
        }
    }.run);
}

// Test buffered input with parseNumber
test "lexer: parse number with buffered input" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            const input = "123.45e-2";
            var fbs = std.io.fixedBufferStream(input);
            const buffered_input = zjson.BufferedInput(@TypeOf(fbs.reader())).init(fbs.reader());
            var lexer = zjson.BufferedLexer(@TypeOf(fbs.reader())).init(buffered_input, allocator);
            defer lexer.deinit();

            const result = try lexer.parseNumber();
            defer allocator.free(result);

            try std.testing.expectEqualStrings("123.45e-2", result);
        }
    }.run);
}

// Test buffered input with surrogate pairs
test "lexer: parse surrogate pair with buffered input" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            const input = "\"\\uD83D\\uDE00\""; // 😀
            var fbs = std.io.fixedBufferStream(input);
            const buffered_input = zjson.BufferedInput(@TypeOf(fbs.reader())).init(fbs.reader());
            var lexer = zjson.BufferedLexer(@TypeOf(fbs.reader())).init(buffered_input, allocator);
            defer lexer.deinit();

            const result = try lexer.parseString();
            defer if (result.allocated) allocator.free(result.data);

            try std.testing.expectEqualStrings("😀", result.data);
            try std.testing.expect(result.allocated);
        }
    }.run);
}

// Test empty string
test "lexer: parse empty string (slice)" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            const input = "\"\"";
            const slice_input = zjson.SliceInput.init(input);
            var lexer = zjson.SliceLexer.init(slice_input, allocator);

            const result = try lexer.parseString();
            defer if (result.allocated) allocator.free(result.data);

            try std.testing.expectEqualStrings("", result.data);
        }
    }.run);
}

// Test string with all escape sequences
test "lexer: parse string with all escapes (slice)" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            const input = "\"\\\"\\\\,\\/,\\b,\\f,\\n,\\r,\\t\"";
            const slice_input = zjson.SliceInput.init(input);
            var lexer = zjson.SliceLexer.init(slice_input, allocator);

            const result = try lexer.parseString();
            defer if (result.allocated) allocator.free(result.data);

            try std.testing.expectEqualStrings("\"\\,/,\x08,\x0C,\n,\r,\t", result.data);
        }
    }.run);
}

// Test large number
test "lexer: parse large number (slice)" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            const input = "9999999999999999999999999999";
            const slice_input = zjson.SliceInput.init(input);
            var lexer = zjson.SliceLexer.init(slice_input, allocator);

            const result = try lexer.parseNumber();
            defer allocator.free(result);

            try std.testing.expectEqualStrings("9999999999999999999999999999", result);
        }
    }.run);
}
