const std = @import("std");
const zjson = @import("zjson");

test "json pointer basic navigation" {
    const allocator = std.testing.allocator;

    const json =
        \\{
        \\  "users": [
        \\    {"name": "Alice", "age": 30},
        \\    {"name": "Bob", "age": 25}
        \\  ],
        \\  "count": 2,
        \\  "active": true
        \\}
    ;

    var result = try zjson.parse(json, allocator, .{});
    defer result.deinit();

    // Test root access
    const root = try zjson.pointer.get(result.value, "");
    try std.testing.expect(root == .Object);

    // Test simple field
    const count = try zjson.pointer.get(result.value, "/count");
    try std.testing.expectEqualStrings("2", count.Number);

    // Test nested path
    const name = try zjson.pointer.get(result.value, "/users/0/name");
    try std.testing.expectEqualStrings("Alice", name.String);

    // Test second array element
    const bob_age = try zjson.pointer.get(result.value, "/users/1/age");
    try std.testing.expectEqualStrings("25", bob_age.Number);

    // Test boolean
    const active = try zjson.pointer.get(result.value, "/active");
    try std.testing.expect(active.Bool == true);
}

test "json pointer errors" {
    const allocator = std.testing.allocator;

    const json =
        \\{"users": [{"name": "Alice"}]}
    ;

    var result = try zjson.parse(json, allocator, .{});
    defer result.deinit();

    // Missing key
    try std.testing.expectError(zjson.Error.KeyNotFound, zjson.pointer.get(result.value, "/missing"));

    // Index out of bounds
    try std.testing.expectError(zjson.Error.IndexOutOfBounds, zjson.pointer.get(result.value, "/users/5"));

    // Invalid pointer (no leading /)
    try std.testing.expectError(zjson.Error.InvalidPath, zjson.pointer.get(result.value, "users"));

    // Append marker returns error on read
    try std.testing.expectError(zjson.Error.IndexOutOfBounds, zjson.pointer.get(result.value, "/users/-"));
}

test "json pointer escape sequences" {
    const allocator = std.testing.allocator;

    // Keys with special characters
    const json =
        \\{"a/b": "slash", "a~b": "tilde", "a~1b": "literal"}
    ;

    var result = try zjson.parse(json, allocator, .{});
    defer result.deinit();

    // ~1 escapes /
    const slash = try zjson.pointer.get(result.value, "/a~1b");
    try std.testing.expectEqualStrings("slash", slash.String);

    // ~0 escapes ~
    const tilde = try zjson.pointer.get(result.value, "/a~0b");
    try std.testing.expectEqualStrings("tilde", tilde.String);

    // ~01 means ~1 literal
    const literal = try zjson.pointer.get(result.value, "/a~01b");
    try std.testing.expectEqualStrings("literal", literal.String);
}

test "json pointer getPointerAs" {
    const allocator = std.testing.allocator;

    const json =
        \\{
        \\  "name": "Alice",
        \\  "age": 30,
        \\  "score": 95.5,
        \\  "active": true
        \\}
    ;

    var result = try zjson.parse(json, allocator, .{});
    defer result.deinit();

    const name = try zjson.pointer.getAs([]const u8, result.value, "/name");
    try std.testing.expectEqualStrings("Alice", name);

    const age = try zjson.pointer.getAs(i64, result.value, "/age");
    try std.testing.expectEqual(@as(i64, 30), age);

    const score = try zjson.pointer.getAs(f64, result.value, "/score");
    try std.testing.expectApproxEqAbs(@as(f64, 95.5), score, 0.001);

    const active = try zjson.pointer.getAs(bool, result.value, "/active");
    try std.testing.expect(active == true);
}

test "json pointer hasPointer" {
    const allocator = std.testing.allocator;

    const json =
        \\{"users": [{"name": "Alice"}]}
    ;

    var result = try zjson.parse(json, allocator, .{});
    defer result.deinit();

    try std.testing.expect(zjson.pointer.has(result.value, "/users"));
    try std.testing.expect(zjson.pointer.has(result.value, "/users/0"));
    try std.testing.expect(zjson.pointer.has(result.value, "/users/0/name"));
    try std.testing.expect(!zjson.pointer.has(result.value, "/missing"));
    try std.testing.expect(!zjson.pointer.has(result.value, "/users/5"));
}

test "json pointer deep nesting" {
    const allocator = std.testing.allocator;

    const json =
        \\{"a": {"b": {"c": {"d": {"e": "deep"}}}}}
    ;

    var result = try zjson.parse(json, allocator, .{});
    defer result.deinit();

    const deep = try zjson.pointer.get(result.value, "/a/b/c/d/e");
    try std.testing.expectEqualStrings("deep", deep.String);
}
