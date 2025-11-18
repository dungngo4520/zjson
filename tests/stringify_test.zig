const std = @import("std");
const zjson = @import("zjson");

test "stringify basic types" {
    try std.testing.expectEqualStrings("true", zjson.stringify(true));
    try std.testing.expectEqualStrings("false", zjson.stringify(false));
    try std.testing.expectEqualStrings("42", zjson.stringify(42));
    try std.testing.expectEqualStrings("\"hello\"", zjson.stringify("hello"));
    try std.testing.expectEqualStrings("null", zjson.stringify(null));
}

test "stringify enums" {
    const Color = enum { red, green, blue };
    try std.testing.expectEqualStrings("\"red\"", zjson.stringify(Color.red));
    try std.testing.expectEqualStrings("\"green\"", zjson.stringify(Color.green));
}

test "stringify optionals" {
    try std.testing.expectEqualStrings("\"value\"", zjson.stringify(@as(?[]const u8, "value")));
    try std.testing.expectEqualStrings("null", zjson.stringify(@as(?[]const u8, null)));
}

test "stringify structs" {
    const Person = struct {
        name: []const u8,
        age: u8,
    };
    const person = Person{ .name = "Alice", .age = 30 };
    try std.testing.expectEqualStrings("{\"name\":\"Alice\",\"age\":30}", zjson.stringify(person));
}

test "stringify structs with omitempty" {
    const User = struct {
        name: []const u8,
        email: ?[]const u8 = null,
    };
    const user1 = User{ .name = "Bob", .email = "bob@example.com" };
    const user2 = User{ .name = "Charlie" };
    try std.testing.expectEqualStrings("{\"name\":\"Bob\",\"email\":\"bob@example.com\"}", zjson.stringify(user1));
    try std.testing.expectEqualStrings("{\"name\":\"Charlie\"}", zjson.stringify(user2));
}

test "stringify arrays" {
    const arr = [_]i32{ 1, 2, 3 };
    try std.testing.expectEqualStrings("[1,2,3]", zjson.stringify(&arr));
}
