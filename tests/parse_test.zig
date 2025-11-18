const std = @import("std");
const zjson = @import("zjson");

test "parse basic types" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    {
        const result = try zjson.parse("null", allocator);
        defer zjson.freeValue(result, allocator);
        try std.testing.expect(result == .Null);
    }

    {
        const result = try zjson.parse("true", allocator);
        defer zjson.freeValue(result, allocator);
        try std.testing.expect(result == .Bool and result.Bool == true);
    }

    {
        const result = try zjson.parse("false", allocator);
        defer zjson.freeValue(result, allocator);
        try std.testing.expect(result == .Bool and result.Bool == false);
    }

    {
        const result = try zjson.parse("42", allocator);
        defer zjson.freeValue(result, allocator);
        try std.testing.expect(result == .Number);
        try std.testing.expectEqualStrings("42", result.Number);
    }

    {
        const result = try zjson.parse("\"hello\"", allocator);
        defer zjson.freeValue(result, allocator);
        try std.testing.expect(result == .String);
        try std.testing.expectEqualStrings("hello", result.String);
    }
}

test "parse arrays" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    {
        const result = try zjson.parse("[1,2,3]", allocator);
        defer zjson.freeValue(result, allocator);
        try std.testing.expect(result == .Array);
        try std.testing.expect(result.Array.len == 3);
        try std.testing.expectEqualStrings("1", result.Array[0].Number);
        try std.testing.expectEqualStrings("2", result.Array[1].Number);
        try std.testing.expectEqualStrings("3", result.Array[2].Number);
    }

    {
        const result = try zjson.parse("[]", allocator);
        defer zjson.freeValue(result, allocator);
        try std.testing.expect(result.Array.len == 0);
    }
}

test "parse objects" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const result = try zjson.parse("{\"name\":\"Alice\",\"age\":30}", allocator);
    defer zjson.freeValue(result, allocator);
    try std.testing.expect(result == .Object);
    try std.testing.expect(result.Object.len == 2);
    try std.testing.expectEqualStrings("name", result.Object[0].key);
    try std.testing.expectEqualStrings("Alice", result.Object[0].value.String);
    try std.testing.expectEqualStrings("age", result.Object[1].key);
    try std.testing.expectEqualStrings("30", result.Object[1].value.Number);
}

test "parse complex nested structure" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const json = "{\"users\":[{\"name\":\"Alice\",\"age\":30},{\"name\":\"Bob\",\"age\":25}]}";
    const result = try zjson.parse(json, allocator);
    defer zjson.freeValue(result, allocator);
    try std.testing.expect(result == .Object);
    try std.testing.expectEqualStrings("users", result.Object[0].key);
    try std.testing.expect(result.Object[0].value == .Array);
    try std.testing.expect(result.Object[0].value.Array.len == 2);
}
