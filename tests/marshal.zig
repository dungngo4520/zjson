const std = @import("std");
const zjson = @import("zjson");
const test_utils = @import("test_utils.zig");

test "marshal compile-time basic types" {
    try std.testing.expectEqualStrings("true", zjson.marshal(true, .{}));
    try std.testing.expectEqualStrings("false", zjson.marshal(false, .{}));
    try std.testing.expectEqualStrings("42", zjson.marshal(42, .{}));
    try std.testing.expectEqualStrings("\"hello\"", zjson.marshal("hello", .{}));
    try std.testing.expectEqualStrings("null", zjson.marshal(null, .{}));
}

test "marshal compile-time enums" {
    const Color = enum { red, green, blue };
    try std.testing.expectEqualStrings("\"red\"", zjson.marshal(Color.red, .{}));
    try std.testing.expectEqualStrings("\"green\"", zjson.marshal(Color.green, .{}));
}

test "marshal compile-time optionals" {
    try std.testing.expectEqualStrings("\"value\"", zjson.marshal(@as(?[]const u8, "value"), .{}));
    try std.testing.expectEqualStrings("null", zjson.marshal(@as(?[]const u8, null), .{}));
}

test "marshal compile-time structs" {
    const Person = struct {
        name: []const u8,
        age: u8,
    };
    const person = Person{ .name = "Alice", .age = 30 };
    try std.testing.expectEqualStrings("{\"name\":\"Alice\",\"age\":30}", zjson.marshal(person, .{}));
}

test "marshal compile-time structs with omitempty" {
    const User = struct {
        name: []const u8,
        email: ?[]const u8 = null,
    };
    const user1 = User{ .name = "Bob", .email = "bob@example.com" };
    const user2 = User{ .name = "Charlie" };
    try std.testing.expectEqualStrings("{\"name\":\"Bob\",\"email\":\"bob@example.com\"}", zjson.marshal(user1, .{}));
    try std.testing.expectEqualStrings("{\"name\":\"Charlie\"}", zjson.marshal(user2, .{}));
}

test "marshal compile-time arrays" {
    const arr = [_]i32{ 1, 2, 3 };
    try std.testing.expectEqualStrings("[1,2,3]", zjson.marshal(&arr, .{}));
}

test "marshal runtime values" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            const bool_json = try zjson.marshalAlloc(true, allocator, .{});
            defer allocator.free(bool_json);
            try std.testing.expectEqualSlices(u8, "true", bool_json);

            const null_json = try zjson.marshalAlloc(@as(?u32, null), allocator, .{});
            defer allocator.free(null_json);
            try std.testing.expectEqualSlices(u8, "null", null_json);

            const num_json = try zjson.marshalAlloc(@as(i32, 42), allocator, .{});
            defer allocator.free(num_json);
            try std.testing.expectEqualSlices(u8, "42", num_json);

            const str_json = try zjson.marshalAlloc("hello", allocator, .{});
            defer allocator.free(str_json);
            try std.testing.expectEqualSlices(u8, "\"hello\"", str_json);

            const nums = [_]i32{ 1, 2, 3 };
            const array_json = try zjson.marshalAlloc(&nums, allocator, .{});
            defer allocator.free(array_json);
            try std.testing.expectEqualSlices(u8, "[1,2,3]", array_json);

            const Person = struct {
                name: []const u8,
                age: u32,
            };
            const person = Person{ .name = "Alice", .age = 30 };
            const person_json = try zjson.marshalAlloc(person, allocator, .{});
            defer allocator.free(person_json);
            try std.testing.expectEqualSlices(u8, "{\"name\":\"Alice\",\"age\":30}", person_json);

            const User = struct {
                name: []const u8,
                email: ?[]const u8 = null,
            };
            const user = User{ .name = "Bob" };
            const user_json = try zjson.marshalAlloc(user, allocator, .{});
            defer allocator.free(user_json);
            try std.testing.expectEqualSlices(u8, "{\"name\":\"Bob\"}", user_json);

            const Status = enum { active, inactive };
            const enum_json = try zjson.marshalAlloc(Status.active, allocator, .{});
            defer allocator.free(enum_json);
            try std.testing.expectEqualSlices(u8, "\"active\"", enum_json);
        }
    }.run);
}

test "marshal runtime string hashmap" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            var map = std.StringHashMap(u32).init(allocator);
            defer map.deinit();

            try map.put("bananas", 2);
            try map.put("apples", 1);
            try map.put("oranges", 3);

            const json = try zjson.marshalAlloc(map, allocator, .{ .sort_keys = true });
            defer allocator.free(json);
            try std.testing.expectEqualSlices(u8, "{\"apples\":1,\"bananas\":2,\"oranges\":3}", json);
        }
    }.run);
}

test "marshal runtime string hashmap unmanaged" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            var map = std.StringHashMapUnmanaged(u32){};
            defer map.deinit(allocator);

            try map.put(allocator, "x", 10);
            try map.put(allocator, "y", 20);

            const json = try zjson.marshalAlloc(map, allocator, .{ .sort_keys = true });
            defer allocator.free(json);
            try std.testing.expectEqualSlices(u8, "{\"x\":10,\"y\":20}", json);
        }
    }.run);
}

test "marshal runtime string hashmap complex values" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            const Stats = struct {
                min: i32,
                max: i32,
                info: struct { label: []const u8 },
            };

            var map = std.StringHashMap(Stats).init(allocator);
            defer map.deinit();

            try map.put("alpha", .{ .min = -5, .max = 10, .info = .{ .label = "slow" } });
            try map.put("beta", .{ .min = 0, .max = 42, .info = .{ .label = "fast" } });

            const json = try zjson.marshalAlloc(map, allocator, .{ .sort_keys = true });
            defer allocator.free(json);

            const expected = "{\"alpha\":{\"info\":{\"label\":\"slow\"},\"max\":10,\"min\":-5},\"beta\":{\"info\":{\"label\":\"fast\"},\"max\":42,\"min\":0}}";
            try std.testing.expectEqualSlices(u8, expected, json);
        }
    }.run);
}

test "marshal runtime arraylist unmanaged simple values" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            var list = try std.ArrayList(i32).initCapacity(allocator, 3);
            defer list.deinit(allocator);

            try list.append(allocator, 1);
            try list.append(allocator, 2);
            try list.append(allocator, 3);

            const json = try zjson.marshalAlloc(list, allocator, .{});
            defer allocator.free(json);
            try std.testing.expectEqualSlices(u8, "[1,2,3]", json);
        }
    }.run);
}

test "marshal runtime arraylist unmanaged complex values" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            const Entry = struct {
                name: []const u8,
                meta: struct {
                    active: bool,
                    tag: []const u8,
                },
            };

            var list = try std.ArrayList(Entry).initCapacity(allocator, 2);
            defer list.deinit(allocator);

            try list.append(allocator, Entry{ .name = "alpha", .meta = .{ .active = true, .tag = "primary" } });
            try list.append(allocator, Entry{ .name = "beta", .meta = .{ .active = false, .tag = "secondary" } });

            const json = try zjson.marshalAlloc(list, allocator, .{});
            defer allocator.free(json);

            const expected = "[{\"name\":\"alpha\",\"meta\":{\"active\":true,\"tag\":\"primary\"}},{\"name\":\"beta\",\"meta\":{\"active\":false,\"tag\":\"secondary\"}}]";
            try std.testing.expectEqualSlices(u8, expected, json);
        }
    }.run);
}
