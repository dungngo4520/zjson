const std = @import("std");
const zjson = @import("zjson");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Example 1: Runtime stringify simple values
    const hello = try zjson.stringifyAlloc("hello", allocator);
    defer allocator.free(hello);
    std.debug.print("String: {s}\n", .{hello});

    const num = try zjson.stringifyAlloc(@as(i32, 42), allocator);
    defer allocator.free(num);
    std.debug.print("Number: {s}\n", .{num});

    // Example 2: Runtime stringify struct
    const Person = struct {
        name: []const u8,
        age: u32,
    };

    const person = Person{ .name = "Alice", .age = 30 };
    const person_json = try zjson.stringifyAlloc(person, allocator);
    defer allocator.free(person_json);
    std.debug.print("Person: {s}\n", .{person_json});

    // Example 3: Runtime stringify array
    const numbers = [_]i32{ 1, 2, 3, 4, 5 };
    const array_json = try zjson.stringifyAlloc(&numbers, allocator);
    defer allocator.free(array_json);
    std.debug.print("Array: {s}\n", .{array_json});

    // Example 4: Runtime stringify struct with optional fields
    const User = struct {
        username: []const u8,
        email: ?[]const u8 = null,
        verified: ?bool = null,
    };

    const user1 = User{ .username = "bob", .email = "bob@example.com", .verified = true };
    const user2 = User{ .username = "charlie" };

    const user1_json = try zjson.stringifyAlloc(user1, allocator);
    defer allocator.free(user1_json);
    std.debug.print("User 1: {s}\n", .{user1_json});

    const user2_json = try zjson.stringifyAlloc(user2, allocator);
    defer allocator.free(user2_json);
    std.debug.print("User 2: {s}\n", .{user2_json});
}
