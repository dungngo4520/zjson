const std = @import("std");
const zjson = @import("zjson");

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

test "stringify runtime bool" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const result = try zjson.stringifyAlloc(true, allocator, .{});
    defer allocator.free(result);
    try std.testing.expectEqualSlices(u8, "true", result);
}

test "stringify runtime null" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const result = try zjson.stringifyAlloc(@as(?u32, null), allocator, .{});
    defer allocator.free(result);
    try std.testing.expectEqualSlices(u8, "null", result);
}

test "stringify runtime number" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const result = try zjson.stringifyAlloc(@as(i32, 42), allocator, .{});
    defer allocator.free(result);
    try std.testing.expectEqualSlices(u8, "42", result);
}

test "stringify runtime string" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const result = try zjson.stringifyAlloc("hello", allocator, .{});
    defer allocator.free(result);
    try std.testing.expectEqualSlices(u8, "\"hello\"", result);
}

test "stringify runtime array" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const nums = [_]i32{ 1, 2, 3 };
    const result = try zjson.stringifyAlloc(&nums, allocator, .{});
    defer allocator.free(result);
    try std.testing.expectEqualSlices(u8, "[1,2,3]", result);
}

test "stringify runtime struct" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const Person = struct {
        name: []const u8,
        age: u32,
    };

    const person = Person{ .name = "Alice", .age = 30 };
    const result = try zjson.stringifyAlloc(person, allocator, .{});
    defer allocator.free(result);
    try std.testing.expectEqualSlices(u8, "{\"name\":\"Alice\",\"age\":30}", result);
}

test "stringify runtime struct with optional fields" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const User = struct {
        name: []const u8,
        email: ?[]const u8 = null,
    };

    const user = User{ .name = "Bob" };
    const result = try zjson.stringifyAlloc(user, allocator, .{});
    defer allocator.free(result);
    try std.testing.expectEqualSlices(u8, "{\"name\":\"Bob\"}", result);
}

test "stringify runtime enum" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const Status = enum { active, inactive };
    const result = try zjson.stringifyAlloc(Status.active, allocator, .{});
    defer allocator.free(result);
    try std.testing.expectEqualSlices(u8, "\"active\"", result);
}
