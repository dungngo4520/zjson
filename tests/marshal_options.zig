const std = @import("std");
const zjson = @import("zjson");
const test_utils = @import("test_utils.zig");

test "marshal use_tabs option" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            const Data = struct {
                name: []const u8,
                age: u32,
            };
            const data = Data{ .name = "Alice", .age = 30 };

            const json = try zjson.marshalAlloc(data, allocator, .{
                .pretty = true,
                .indent = 1,
                .use_tabs = true,
            });
            defer allocator.free(json);

            const expected = "{\n\t\"name\": \"Alice\",\n\t\"age\": 30\n}";
            try std.testing.expectEqualSlices(u8, expected, json);
        }
    }.run);
}

test "marshal line_ending crlf" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            const Data = struct {
                x: i32,
                y: i32,
            };
            const data = Data{ .x = 10, .y = 20 };

            const json = try zjson.marshalAlloc(data, allocator, .{
                .pretty = true,
                .indent = 2,
                .line_ending = .crlf,
            });
            defer allocator.free(json);

            const expected = "{\r\n  \"x\": 10,\r\n  \"y\": 20\r\n}";
            try std.testing.expectEqualSlices(u8, expected, json);
        }
    }.run);
}

test "marshal compact_arrays simple" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            const data = [_]i32{ 1, 2, 3, 4, 5 };

            const json = try zjson.marshalAlloc(data, allocator, .{
                .pretty = true,
                .indent = 2,
                .compact_arrays = true,
            });
            defer allocator.free(json);

            const expected = "[1, 2, 3, 4, 5]";
            try std.testing.expectEqualSlices(u8, expected, json);
        }
    }.run);
}

test "marshal compact_arrays with ArrayList" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            var list = try std.ArrayList([]const u8).initCapacity(allocator, 3);
            defer list.deinit(allocator);

            try list.append(allocator, "apple");
            try list.append(allocator, "banana");
            try list.append(allocator, "cherry");

            const json = try zjson.marshalAlloc(list, allocator, .{
                .pretty = true,
                .indent = 2,
                .compact_arrays = true,
            });
            defer allocator.free(json);

            const expected = "[\"apple\", \"banana\", \"cherry\"]";
            try std.testing.expectEqualSlices(u8, expected, json);
        }
    }.run);
}

test "marshal compact_arrays false with regular formatting" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            const data = [_]i32{ 1, 2, 3 };

            const json = try zjson.marshalAlloc(data, allocator, .{
                .pretty = true,
                .indent = 2,
                .compact_arrays = false,
            });
            defer allocator.free(json);

            const expected = "[\n  1,\n  2,\n  3\n]";
            try std.testing.expectEqualSlices(u8, expected, json);
        }
    }.run);
}

test "marshal sort_keys with runtime struct" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            const Data = struct {
                zebra: i32,
                apple: i32,
                mango: i32,
            };
            const data = Data{ .zebra = 1, .apple = 2, .mango = 3 };

            const json = try zjson.marshalAlloc(data, allocator, .{
                .sort_keys = true,
            });
            defer allocator.free(json);

            const expected = "{\"apple\":2,\"mango\":3,\"zebra\":1}";
            try std.testing.expectEqualSlices(u8, expected, json);
        }
    }.run);
}

test "marshal sort_keys with pretty printing" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            const Data = struct {
                zoo: []const u8,
                bar: bool,
                apple: i32,
            };
            const data = Data{ .zoo = "animals", .bar = true, .apple = 42 };

            const json = try zjson.marshalAlloc(data, allocator, .{
                .pretty = true,
                .indent = 2,
                .sort_keys = true,
            });
            defer allocator.free(json);

            const expected = "{\n  \"apple\": 42,\n  \"bar\": true,\n  \"zoo\": \"animals\"\n}";
            try std.testing.expectEqualSlices(u8, expected, json);
        }
    }.run);
}

test "marshal sort_keys with HashMap" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            var map = std.StringHashMap(i32).init(allocator);
            defer map.deinit();

            try map.put("zebra", 1);
            try map.put("apple", 2);
            try map.put("mango", 3);
            try map.put("banana", 4);

            const json = try zjson.marshalAlloc(map, allocator, .{
                .sort_keys = true,
            });
            defer allocator.free(json);

            const expected = "{\"apple\":2,\"banana\":4,\"mango\":3,\"zebra\":1}";
            try std.testing.expectEqualSlices(u8, expected, json);
        }
    }.run);
}

test "marshal combined options: tabs + crlf + compact_arrays" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            const Data = struct {
                name: []const u8,
                tags: [3][]const u8,
            };
            const data = Data{ .name = "test", .tags = [_][]const u8{ "a", "b", "c" } };

            const json = try zjson.marshalAlloc(data, allocator, .{
                .pretty = true,
                .indent = 1,
                .use_tabs = true,
                .line_ending = .crlf,
                .compact_arrays = true,
            });
            defer allocator.free(json);

            const expected = "{\r\n\t\"name\": \"test\",\r\n\t\"tags\": [\"a\", \"b\", \"c\"]\r\n}";
            try std.testing.expectEqualSlices(u8, expected, json);
        }
    }.run);
}

test "marshal combined options: all enabled" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            const Data = struct {
                zebra: i32,
                apple: []const u8,
                numbers: [2]i32,
            };
            const data = Data{ .zebra = 99, .apple = "fruit", .numbers = [_]i32{ 1, 2 } };

            const json = try zjson.marshalAlloc(data, allocator, .{
                .pretty = true,
                .indent = 1,
                .use_tabs = true,
                .line_ending = .crlf,
                .compact_arrays = true,
                .sort_keys = true,
            });
            defer allocator.free(json);

            const expected = "{\r\n\t\"apple\": \"fruit\",\r\n\t\"numbers\": [1, 2],\r\n\t\"zebra\": 99\r\n}";
            try std.testing.expectEqualSlices(u8, expected, json);
        }
    }.run);
}
