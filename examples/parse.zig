const std = @import("std");
const zjson = @import("zjson");

const Sample = struct {
    label: []const u8,
    json: []const u8,
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const scalars = [_]Sample{
        .{ .label = "null", .json = "null" },
        .{ .label = "true", .json = "true" },
        .{ .label = "false", .json = "false" },
        .{ .label = "number", .json = "42" },
        .{ .label = "string", .json = "\"hello\"" },
    };

    inline for (scalars) |sample| {
        var parsed = try zjson.parse(sample.json, allocator, .{});
        defer parsed.deinit();
        std.debug.print("{s}: {s}\n", .{ sample.label, @tagName(parsed.value) });
    }

    var array_result = try zjson.parse("[1,2,3,4,5]", allocator, .{});
    defer array_result.deinit();
    std.debug.print("array len={d}\n", .{array_result.value.Array.len});

    const object_json = "{\"name\":\"Alice\",\"age\":30}";
    var object_result = try zjson.parse(object_json, allocator, .{});
    defer object_result.deinit();
    std.debug.print("first field: {s}\n", .{object_result.value.Object[0].key});

    const nested_json =
        \\{
        \\  "users": [
        \\    {"name": "Alice", "age": 30},
        \\    {"name": "Bob", "age": 25}
        \\  ],
        \\  "count": 2
        \\}
    ;
    var nested_result = try zjson.parse(nested_json, allocator, .{});
    defer nested_result.deinit();
    const users = nested_result.value.Object[0].value.Array;
    std.debug.print("nested users={d}, first={s}\n", .{ users.len, users[0].Object[0].value.String });

    const escaped_json = "\"Hello\\nWorld\"";
    var escaped_result = try zjson.parse(escaped_json, allocator, .{});
    defer escaped_result.deinit();
    std.debug.print("escaped: {s}\n", .{escaped_result.value.String});

    var invalid = zjson.parse("{invalid json}", allocator, .{});
    if (invalid) |*parsed| {
        parsed.deinit();
        std.debug.print("unexpected success\n", .{});
    } else |err| {
        std.debug.print("error: {}\n", .{err});
    }
}
