const std = @import("std");
const zjson = @import("zjson");
const test_utils = @import("test_utils.zig");

test "parse scalars" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            try test_utils.withParsed("null", allocator, .{}, struct {
                fn check(value: zjson.Value, arena: std.mem.Allocator) !void {
                    _ = arena;
                    try expectTag(value, .Null);
                }
            }.check);

            const bool_cases = [_]struct { json: []const u8, expected: bool }{
                .{ .json = "true", .expected = true },
                .{ .json = "false", .expected = false },
            };
            inline for (bool_cases) |case| {
                const expected = case.expected;
                try test_utils.withParsed(case.json, allocator, .{}, struct {
                    fn check(value: zjson.Value, arena: std.mem.Allocator) !void {
                        _ = arena;
                        try expectBool(value, expected);
                    }
                }.check);
            }

            try test_utils.withParsed("42", allocator, .{}, struct {
                fn check(value: zjson.Value, arena: std.mem.Allocator) !void {
                    _ = arena;
                    try expectNumber(value, "42");
                }
            }.check);

            try test_utils.withParsed("\"hello\"", allocator, .{}, struct {
                fn check(value: zjson.Value, arena: std.mem.Allocator) !void {
                    _ = arena;
                    try expectString(value, "hello");
                }
            }.check);
        }
    }.run);
}

test "parse arrays" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            try test_utils.withParsed("[1,2,3]", allocator, .{}, struct {
                fn check(value: zjson.Value, arena: std.mem.Allocator) !void {
                    _ = arena;
                    try expectTag(value, .Array);
                    try std.testing.expectEqual(@as(usize, 3), value.Array.len);
                    try std.testing.expectEqualStrings("1", value.Array[0].Number);
                    try std.testing.expectEqualStrings("2", value.Array[1].Number);
                    try std.testing.expectEqualStrings("3", value.Array[2].Number);
                }
            }.check);

            try test_utils.withParsed("[]", allocator, .{}, struct {
                fn check(value: zjson.Value, arena: std.mem.Allocator) !void {
                    _ = arena;
                    try expectTag(value, .Array);
                    try std.testing.expectEqual(@as(usize, 0), value.Array.len);
                }
            }.check);
        }
    }.run);
}

test "parse objects" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            try test_utils.withParsed("{\"name\":\"Alice\",\"age\":30}", allocator, .{}, struct {
                fn check(value: zjson.Value, arena: std.mem.Allocator) !void {
                    _ = arena;
                    try expectTag(value, .Object);
                    try std.testing.expectEqual(@as(usize, 2), value.Object.len);
                    try std.testing.expectEqualStrings("name", value.Object[0].key);
                    try std.testing.expectEqualStrings("Alice", value.Object[0].value.String);
                    try std.testing.expectEqualStrings("age", value.Object[1].key);
                    try std.testing.expectEqualStrings("30", value.Object[1].value.Number);
                }
            }.check);
        }
    }.run);
}

test "parse nested structures" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            const json = "{\"users\":[{\"name\":\"Alice\",\"age\":30},{\"name\":\"Bob\",\"age\":25}]}";
            try test_utils.withParsed(json, allocator, .{}, struct {
                fn check(value: zjson.Value, arena: std.mem.Allocator) !void {
                    _ = arena;
                    try expectTag(value, .Object);
                    try std.testing.expectEqualStrings("users", value.Object[0].key);
                    try expectTag(value.Object[0].value, .Array);
                    try std.testing.expectEqual(@as(usize, 2), value.Object[0].value.Array.len);
                }
            }.check);
        }
    }.run);
}

test "parse deeply nested arrays" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            const depth = 5000;
            var source = try std.ArrayList(u8).initCapacity(std.testing.allocator, depth * 2 + 32);
            defer source.deinit(std.testing.allocator);

            for (0..depth) |_| {
                try source.append(std.testing.allocator, '[');
            }
            try source.append(std.testing.allocator, '0');
            for (0..depth) |_| {
                try source.append(std.testing.allocator, ']');
            }

            var parsed = try zjson.parse(source.items, allocator, .{ .max_depth = 10000 });
            defer parsed.deinit();

            var current = parsed.value;
            var remaining: usize = depth;
            while (remaining > 0) : (remaining -= 1) {
                try expectTag(current, .Array);
                try std.testing.expectEqual(@as(usize, 1), current.Array.len);
                current = current.Array[0];
            }
            try expectNumber(current, "0");
        }
    }.run);
}

test "parse with trailing commas" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            try test_utils.withParsed("[1,2,3,]", allocator, .{ .allow_trailing_commas = true }, struct {
                fn check(value: zjson.Value, arena: std.mem.Allocator) !void {
                    _ = arena;
                    try expectTag(value, .Array);
                    try std.testing.expectEqual(@as(usize, 3), value.Array.len);
                }
            }.check);

            try test_utils.withParsed("{\"a\":1,\"b\":2,}", allocator, .{ .allow_trailing_commas = true }, struct {
                fn check(value: zjson.Value, arena: std.mem.Allocator) !void {
                    _ = arena;
                    try expectTag(value, .Object);
                    try std.testing.expectEqual(@as(usize, 2), value.Object.len);
                }
            }.check);
        }
    }.run);
}

test "parse with comments" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            try test_utils.withParsed("[1, /* comment */ 2, 3]", allocator, .{ .allow_comments = true }, struct {
                fn check(value: zjson.Value, arena: std.mem.Allocator) !void {
                    _ = arena;
                    try expectTag(value, .Array);
                    try std.testing.expectEqual(@as(usize, 3), value.Array.len);
                }
            }.check);

            try test_utils.withParsed("// line comment\n{\"a\": 1}", allocator, .{ .allow_comments = true }, struct {
                fn check(value: zjson.Value, arena: std.mem.Allocator) !void {
                    _ = arena;
                    try expectTag(value, .Object);
                    try std.testing.expectEqual(@as(usize, 1), value.Object.len);
                }
            }.check);
        }
    }.run);
}

test "parse errors" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            const cases = [_]struct {
                json: []const u8,
                options: zjson.ParseOptions = .{},
                err: zjson.Error,
            }{
                .{ .json = "{\"a\": 1", .err = zjson.Error.UnexpectedEnd },
                .{ .json = "[1,]", .err = zjson.Error.InvalidSyntax },
                .{ .json = "{\"a\": tru}", .err = zjson.Error.InvalidSyntax },
                .{ .json = "{\"a\":1} xyz", .err = zjson.Error.TrailingCharacters },
            };

            inline for (cases) |case| {
                try std.testing.expectError(case.err, zjson.parse(case.json, allocator, case.options));
            }
        }
    }.run);
}

test "parse error info" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            const bad = "{\n  \"a\": 1,\n  \"b\":\n}";
            try std.testing.expectError(zjson.Error.InvalidSyntax, zjson.parse(bad, allocator, .{}));
            const info_opt = zjson.lastParseErrorInfo();
            try std.testing.expect(info_opt != null);
            const info = info_opt.?;
            try std.testing.expectEqual(@as(usize, 4), info.line);
            try std.testing.expectEqual(@as(usize, 1), info.column);
            try std.testing.expect(info.context.len > 0);
        }
    }.run);
}

test "write parse error indicator" {
    var buf = try std.ArrayList(u8).initCapacity(std.testing.allocator, 0);
    defer buf.deinit(std.testing.allocator);

    const info = zjson.ParseErrorInfo{
        .byte_offset = 8,
        .line = 2,
        .column = 4,
        .context = "good\nbad value\nrest",
        .context_offset = 0,
    };

    const writer = buf.writer(std.testing.allocator);
    try zjson.writeParseErrorIndicator(info, writer);
    try std.testing.expectEqualStrings("line 2, column 4\nbad value\n   ^\n", buf.items);
}

const ValueTag = std.meta.Tag(zjson.Value);

fn expectTag(value: zjson.Value, tag: ValueTag) !void {
    try std.testing.expect(value == tag);
}

fn expectBool(value: zjson.Value, expected: bool) !void {
    try expectTag(value, .Bool);
    try std.testing.expectEqual(expected, value.Bool);
}

fn expectNumber(value: zjson.Value, expected: []const u8) !void {
    try expectTag(value, .Number);
    try std.testing.expectEqualStrings(expected, value.Number);
}

fn expectString(value: zjson.Value, expected: []const u8) !void {
    try expectTag(value, .String);
    try std.testing.expectEqualStrings(expected, value.String);
}

test "recursion depth limit" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            // Use a pre-computed deeply nested JSON string
            // Testing with max_depth option set to 5
            const deeply_nested = "[[[[[[0]]]]]]"; // 6 levels of nesting

            // This should parse fine with default max_depth
            var result1 = try zjson.parse(deeply_nested, allocator, .{});
            defer result1.deinit();

            // This should fail with max_depth=5 (only allows 5 levels, not 6)
            const result2 = zjson.parse(deeply_nested, allocator, .{ .max_depth = 5 });
            try std.testing.expectError(zjson.Error.MaxDepthExceeded, result2);
        }
    }.run);
}

test "document size limit" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            // Create a document that exceeds max_document_size
            const large_doc = try allocator.alloc(u8, 11_000_000);
            defer allocator.free(large_doc);
            @memset(large_doc, '"');

            // Should exceed default max_document_size of 10MB
            const result = zjson.parse(large_doc, allocator, .{});
            try std.testing.expectError(zjson.Error.DocumentTooLarge, result);
        }
    }.run);
}

test "duplicate key error policy" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            const json = "{\"key\":1,\"key\":2}";

            // Test error policy
            const result = zjson.parse(json, allocator, .{ .duplicate_key_policy = .reject });
            try std.testing.expectError(zjson.Error.DuplicateKey, result);
        }
    }.run);
}

test "duplicate key keep_first policy" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            const json = "{\"a\":1,\"b\":2,\"a\":3}";

            // Test keep_first policy (should keep value 1 for key "a")
            var result = try zjson.parse(json, allocator, .{ .duplicate_key_policy = .keep_first });
            defer result.deinit();

            const obj = result.value.Object;
            try std.testing.expectEqual(@as(usize, 2), obj.len);

            // Find "a" and verify it has value 1
            for (obj) |pair| {
                if (std.mem.eql(u8, pair.key, "a")) {
                    try std.testing.expectEqualStrings("1", pair.value.Number);
                }
            }
        }
    }.run);
}

test "duplicate key keep_last policy" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            const json = "{\"a\":1,\"b\":2,\"a\":3}";

            // Test keep_last policy (default, should keep value 3 for key "a")
            var result = try zjson.parse(json, allocator, .{ .duplicate_key_policy = .keep_last });
            defer result.deinit();

            const obj = result.value.Object;
            try std.testing.expectEqual(@as(usize, 2), obj.len);

            // Find "a" and verify it has value 3
            for (obj) |pair| {
                if (std.mem.eql(u8, pair.key, "a")) {
                    try std.testing.expectEqualStrings("3", pair.value.Number);
                }
            }
        }
    }.run);
}

test "improved error context with hints" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            // Test error with missing closing bracket
            const bad_array = "[1, 2, 3";
            _ = zjson.parse(bad_array, allocator, .{}) catch {};
            const info1 = zjson.lastParseErrorInfo();
            try std.testing.expect(info1 != null);
            try std.testing.expect(info1.?.suggested_fix.len > 0);
        }
    }.run);
}
