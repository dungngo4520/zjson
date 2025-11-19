const std = @import("std");
const zjson = @import("zjson");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Example 1: Parse null and booleans
    {
        const null_result = try zjson.parse("null", allocator, .{});
        defer zjson.freeValue(null_result, allocator);
        std.debug.print("Parsed null: {}\n", .{null_result == .Null});

        const true_result = try zjson.parse("true", allocator, .{});
        defer zjson.freeValue(true_result, allocator);
        std.debug.print("Parsed true: {}\n", .{true_result.Bool});
    }

    // Example 2: Parse numbers
    {
        const number_result = try zjson.parse("42", allocator, .{});
        defer zjson.freeValue(number_result, allocator);
        std.debug.print("Parsed number: {s}\n", .{number_result.Number});
    }

    // Example 3: Parse strings
    {
        const string_result = try zjson.parse("\"hello world\"", allocator, .{});
        defer zjson.freeValue(string_result, allocator);
        std.debug.print("Parsed string: {s}\n", .{string_result.String});
    }

    // Example 4: Parse arrays
    {
        const array_result = try zjson.parse("[1, 2, 3, 4, 5]", allocator, .{});
        defer zjson.freeValue(array_result, allocator);

        std.debug.print("Array with {d} elements: ", .{array_result.Array.len});
        for (array_result.Array) |value| {
            std.debug.print("{s} ", .{value.Number});
        }
        std.debug.print("\n", .{});
    }

    // Example 5: Parse objects
    {
        const json = "{\"name\": \"Alice\", \"age\": 30, \"active\": true}";
        const obj_result = try zjson.parse(json, allocator, .{});
        defer zjson.freeValue(obj_result, allocator);

        std.debug.print("Object with {d} fields:\n", .{obj_result.Object.len});
        for (obj_result.Object) |pair| {
            std.debug.print("  {s}: ", .{pair.key});
            switch (pair.value) {
                .String => |s| std.debug.print("{s}\n", .{s}),
                .Number => |n| std.debug.print("{s}\n", .{n}),
                .Bool => |b| std.debug.print("{}\n", .{b}),
                else => std.debug.print("(other type)\n", .{}),
            }
        }
    }

    // Example 6: Parse nested structures
    {
        const nested_json =
            \\{
            \\  "users": [
            \\    {"name": "Alice", "age": 30},
            \\    {"name": "Bob", "age": 25}
            \\  ],
            \\  "count": 2
            \\}
        ;
        const nested_result = try zjson.parse(nested_json, allocator, .{});
        defer zjson.freeValue(nested_result, allocator);

        const users_pair = nested_result.Object[0];
        std.debug.print("Found array '{s}' with {d} items\n", .{ users_pair.key, users_pair.value.Array.len });
    }

    // Example 7: Parse strings with escaping
    {
        const escaped_json = "\"Hello\\nWorld\\t\\\"Quoted\\\"\"";
        const escaped_result = try zjson.parse(escaped_json, allocator, .{});
        defer zjson.freeValue(escaped_result, allocator);
        std.debug.print("Escaped string: {s}\n", .{escaped_result.String});
    }

    // Example 8: Error handling
    {
        const invalid_json = "{invalid json}";
        if (zjson.parse(invalid_json, allocator, .{})) |_| {
            std.debug.print("Unexpectedly parsed invalid JSON\n", .{});
        } else |err| {
            std.debug.print("Error parsing invalid JSON: {}\n", .{err});
        }
    }
}
