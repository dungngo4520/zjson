const std = @import("std");
const zjson = @import("zjson");

test "stringify with string escaping" {
    try std.testing.expectEqualStrings("\"hello\\nworld\"", zjson.stringify("hello\nworld"));
    try std.testing.expectEqualStrings("\"quote:\\\"test\\\"\"", zjson.stringify("quote:\"test\""));
    try std.testing.expectEqualStrings("\"backslash:\\\\path\"", zjson.stringify("backslash:\\path"));
    try std.testing.expectEqualStrings("\"tab:\\there\"", zjson.stringify("tab:\there"));
}

test "parse strings with escaping" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    {
        const result = try zjson.parse("\"hello\\nworld\"", allocator);
        defer zjson.freeValue(result, allocator);
        try std.testing.expectEqualStrings("hello\nworld", result.String);
    }

    {
        const result = try zjson.parse("\"quote:\\\"test\\\"\"", allocator);
        defer zjson.freeValue(result, allocator);
        try std.testing.expectEqualStrings("quote:\"test\"", result.String);
    }

    {
        const result = try zjson.parse("\"\\\\\"", allocator);
        defer zjson.freeValue(result, allocator);
        try std.testing.expectEqualStrings("\\", result.String);
    }
}
