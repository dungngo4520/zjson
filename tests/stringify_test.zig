const std = @import("std");
const zjson = @import("zjson");
const test_utils = @import("test_utils.zig");

test "stringify compile-time basic types" {
    try std.testing.expectEqualStrings("true", zjson.stringify(true, .{}));
    try std.testing.expectEqualStrings("false", zjson.stringify(false, .{}));
    try std.testing.expectEqualStrings("42", zjson.stringify(42, .{}));
    try std.testing.expectEqualStrings("\"hello\"", zjson.stringify("hello", .{}));
    try std.testing.expectEqualStrings("null", zjson.stringify(null, .{}));
}

test "stringify compile-time enums" {
    const Color = enum { red, green, blue };
    try std.testing.expectEqualStrings("\"red\"", zjson.stringify(Color.red, .{}));
    try std.testing.expectEqualStrings("\"green\"", zjson.stringify(Color.green, .{}));
}

test "stringify compile-time optionals" {
    try std.testing.expectEqualStrings("\"value\"", zjson.stringify(@as(?[]const u8, "value"), .{}));
    try std.testing.expectEqualStrings("null", zjson.stringify(@as(?[]const u8, null), .{}));
}

test "stringify compile-time structs" {
    const Person = struct {
        name: []const u8,
        age: u8,
    };
    const person = Person{ .name = "Alice", .age = 30 };
    try std.testing.expectEqualStrings("{\"name\":\"Alice\",\"age\":30}", zjson.stringify(person, .{}));
}

test "stringify compile-time structs with omitempty" {
    const User = struct {
        name: []const u8,
        email: ?[]const u8 = null,
    };
    const user1 = User{ .name = "Bob", .email = "bob@example.com" };
    const user2 = User{ .name = "Charlie" };
    try std.testing.expectEqualStrings("{\"name\":\"Bob\",\"email\":\"bob@example.com\"}", zjson.stringify(user1, .{}));
    try std.testing.expectEqualStrings("{\"name\":\"Charlie\"}", zjson.stringify(user2, .{}));
}

test "stringify compile-time arrays" {
    const arr = [_]i32{ 1, 2, 3 };
    try std.testing.expectEqualStrings("[1,2,3]", zjson.stringify(&arr, .{}));
}

test "stringify runtime values" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            const bool_json = try zjson.stringifyAlloc(true, allocator, .{});
            defer allocator.free(bool_json);
            try std.testing.expectEqualSlices(u8, "true", bool_json);

            const null_json = try zjson.stringifyAlloc(@as(?u32, null), allocator, .{});
            defer allocator.free(null_json);
            try std.testing.expectEqualSlices(u8, "null", null_json);

            const num_json = try zjson.stringifyAlloc(@as(i32, 42), allocator, .{});
            defer allocator.free(num_json);
            try std.testing.expectEqualSlices(u8, "42", num_json);

            const str_json = try zjson.stringifyAlloc("hello", allocator, .{});
            defer allocator.free(str_json);
            try std.testing.expectEqualSlices(u8, "\"hello\"", str_json);

            const nums = [_]i32{ 1, 2, 3 };
            const array_json = try zjson.stringifyAlloc(&nums, allocator, .{});
            defer allocator.free(array_json);
            try std.testing.expectEqualSlices(u8, "[1,2,3]", array_json);

            const Person = struct {
                name: []const u8,
                age: u32,
            };
            const person = Person{ .name = "Alice", .age = 30 };
            const person_json = try zjson.stringifyAlloc(person, allocator, .{});
            defer allocator.free(person_json);
            try std.testing.expectEqualSlices(u8, "{\"name\":\"Alice\",\"age\":30}", person_json);

            const User = struct {
                name: []const u8,
                email: ?[]const u8 = null,
            };
            const user = User{ .name = "Bob" };
            const user_json = try zjson.stringifyAlloc(user, allocator, .{});
            defer allocator.free(user_json);
            try std.testing.expectEqualSlices(u8, "{\"name\":\"Bob\"}", user_json);

            const Status = enum { active, inactive };
            const enum_json = try zjson.stringifyAlloc(Status.active, allocator, .{});
            defer allocator.free(enum_json);
            try std.testing.expectEqualSlices(u8, "\"active\"", enum_json);
        }
    }.run);
}
