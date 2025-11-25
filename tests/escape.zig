const std = @import("std");
const zjson = @import("zjson");
const escape = zjson.escape;
const test_utils = @import("test_utils.zig");

// Test writeEscapedToArrayList with simple string
test "escape: writeEscapedToArrayList simple string" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            var buffer = std.ArrayList(u8){};
            defer buffer.deinit(allocator);

            try escape.writeEscapedToArrayList(&buffer, allocator, "hello");

            try std.testing.expectEqualStrings("\"hello\"", buffer.items);
        }
    }.run);
}

// Test writeEscapedToArrayList with special characters
test "escape: writeEscapedToArrayList special chars" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            var buffer = std.ArrayList(u8){};
            defer buffer.deinit(allocator);

            try escape.writeEscapedToArrayList(&buffer, allocator, "hello\nworld\t\"test\"\\slash/");

            try std.testing.expectEqualStrings("\"hello\\nworld\\t\\\"test\\\"\\\\slash\\/\"", buffer.items);
        }
    }.run);
}

// Test writeEscapedToArrayList with control characters
test "escape: writeEscapedToArrayList control chars" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            var buffer = std.ArrayList(u8){};
            defer buffer.deinit(allocator);

            try escape.writeEscapedToArrayList(&buffer, allocator, "\x08\x0C");

            try std.testing.expectEqualStrings("\"\\b\\f\"", buffer.items);
        }
    }.run);
}

// Test writeEscapedToArrayList with low control characters (should be \uXXXX)
test "escape: writeEscapedToArrayList low control chars" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            var buffer = std.ArrayList(u8){};
            defer buffer.deinit(allocator);

            try escape.writeEscapedToArrayList(&buffer, allocator, "\x00\x01\x1F");

            try std.testing.expectEqualStrings("\"\\u0000\\u0001\\u001F\"", buffer.items);
        }
    }.run);
}

// Test writeEscapedToWriter with simple string
test "escape: writeEscapedToWriter simple string" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            var buffer = std.ArrayList(u8){};
            defer buffer.deinit(allocator);

            try escape.writeEscapedToWriter(buffer.writer(allocator), "world");

            try std.testing.expectEqualStrings("\"world\"", buffer.items);
        }
    }.run);
}

// Test writeEscapedToWriter with special characters
test "escape: writeEscapedToWriter special chars" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            var buffer = std.ArrayList(u8){};
            defer buffer.deinit(allocator);

            try escape.writeEscapedToWriter(buffer.writer(allocator), "tab\there\nline\rreturn");

            try std.testing.expectEqualStrings("\"tab\\there\\nline\\rreturn\"", buffer.items);
        }
    }.run);
}

// Test escapeStringComptime with simple string
test "escape: escapeStringComptime simple" {
    const result = comptime escape.escapeStringComptime("test");
    try std.testing.expectEqualStrings("\"test\"", result);
}

// Test escapeStringComptime with special characters
test "escape: escapeStringComptime special chars" {
    const result = comptime escape.escapeStringComptime("a\nb\tc\"d\\e/");
    try std.testing.expectEqualStrings("\"a\\nb\\tc\\\"d\\\\e\\/\"", result);
}

// Test escapeStringComptime with control characters
test "escape: escapeStringComptime control chars" {
    const result = comptime escape.escapeStringComptime("\x08\x0C");
    try std.testing.expectEqualStrings("\"\\b\\f\"", result);
}

// Test escapeStringComptime with low control characters
test "escape: escapeStringComptime low control chars" {
    const result = comptime escape.escapeStringComptime("\x00\x1F");
    try std.testing.expectEqualStrings("\"\\u0000\\u001F\"", result);
}

// Test escapeCharComptime
test "escape: escapeCharComptime various" {
    try std.testing.expectEqualStrings("\\\"", comptime escape.escapeCharComptime('"'));
    try std.testing.expectEqualStrings("\\\\", comptime escape.escapeCharComptime('\\'));
    try std.testing.expectEqualStrings("\\n", comptime escape.escapeCharComptime('\n'));
    try std.testing.expectEqualStrings("\\r", comptime escape.escapeCharComptime('\r'));
    try std.testing.expectEqualStrings("\\t", comptime escape.escapeCharComptime('\t'));
    try std.testing.expectEqualStrings("\\b", comptime escape.escapeCharComptime('\x08'));
    try std.testing.expectEqualStrings("\\f", comptime escape.escapeCharComptime('\x0C'));
    try std.testing.expectEqualStrings("\\/", comptime escape.escapeCharComptime('/'));
    try std.testing.expectEqualStrings("a", comptime escape.escapeCharComptime('a'));
    try std.testing.expectEqualStrings("\\u0000", comptime escape.escapeCharComptime('\x00'));
}

// Test empty string
test "escape: empty string" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            var buffer = std.ArrayList(u8){};
            defer buffer.deinit(allocator);

            try escape.writeEscapedToArrayList(&buffer, allocator, "");

            try std.testing.expectEqualStrings("\"\"", buffer.items);
        }
    }.run);
}

// Test writeEscapedToWriter with empty string
test "escape: writeEscapedToWriter empty" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            var buffer = std.ArrayList(u8){};
            defer buffer.deinit(allocator);

            try escape.writeEscapedToWriter(buffer.writer(allocator), "");

            try std.testing.expectEqualStrings("\"\"", buffer.items);
        }
    }.run);
}

// Test escapeStringComptime with empty string
test "escape: escapeStringComptime empty" {
    const result = comptime escape.escapeStringComptime("");
    try std.testing.expectEqualStrings("\"\"", result);
}
