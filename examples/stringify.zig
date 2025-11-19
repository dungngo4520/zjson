const std = @import("std");
const zjson = @import("zjson");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Basic types
    const bool_json = zjson.stringify(true, .{});
    std.debug.print("Boolean: {s}\n", .{bool_json});

    const num_json = zjson.stringify(42, .{});
    std.debug.print("Number: {s}\n", .{num_json});

    const str_json = zjson.stringify("hello", .{});
    std.debug.print("String: {s}\n", .{str_json});

    // Structures
    const Person = struct {
        name: []const u8,
        age: u32,
        email: ?[]const u8 = null,
    };

    const person = Person{
        .name = "Alice",
        .age = 30,
        .email = "alice@example.com",
    };
    const person_json = zjson.stringify(person, .{});
    std.debug.print("Struct: {s}\n", .{person_json});

    // Arrays
    const numbers = [_]i32{ 1, 2, 3 };
    const array_json = zjson.stringify(&numbers, .{});
    std.debug.print("Array: {s}\n", .{array_json});

    // Enums
    const Status = enum { active, inactive };
    const enum_json = zjson.stringify(Status.active, .{});
    std.debug.print("Enum: {s}\n", .{enum_json});

    // Optional fields
    const user1 = Person{
        .name = "Bob",
        .age = 25,
        .email = "bob@example.com",
    };
    const user2 = Person{
        .name = "Charlie",
        .age = 35,
        .email = null,
    };
    std.debug.print("With email: {s}\n", .{zjson.stringify(user1, .{})});
    std.debug.print("Without email: {s}\n", .{zjson.stringify(user2, .{})});

    // Default: compact, omit null
    const json1 = try zjson.stringifyAlloc(person, allocator, .{});
    defer allocator.free(json1);
    std.debug.print("Default: {s}\n", .{json1});

    // Pretty print with indent
    const json2 = try zjson.stringifyAlloc(person, allocator, .{
        .pretty = true,
        .indent = 2,
    });
    defer allocator.free(json2);
    std.debug.print("Pretty:\n{s}\n", .{json2});

    // Include null fields
    const json3 = try zjson.stringifyAlloc(user2, allocator, .{
        .omit_null = false,
    });
    defer allocator.free(json3);
    std.debug.print("With null: {s}\n", .{json3});

    // Array example
    const arr = [_]i32{ 10, 20, 30 };
    const json4 = try zjson.stringifyAlloc(&arr, allocator, .{
        .pretty = true,
        .indent = 2,
    });
    defer allocator.free(json4);
    std.debug.print("Array pretty:\n{s}\n", .{json4});
}
