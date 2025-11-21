const std = @import("std");
const zjson = @import("zjson");

pub fn main() !void {
    const Person = struct {
        name: []const u8,
        age: u32,
        email: ?[]const u8 = null,
    };
    const Status = enum { active, inactive };
    const array = [_]i32{ 1, 2, 3 };

    std.debug.print("bool={s}\n", .{zjson.stringify(true, .{})});
    std.debug.print("num={s}\n", .{zjson.stringify(42, .{})});
    std.debug.print("str={s}\n", .{zjson.stringify("hello", .{})});
    std.debug.print("enum={s}\n", .{zjson.stringify(Status.active, .{})});
    std.debug.print("array={s}\n", .{zjson.stringify(&array, .{})});

    const person = Person{ .name = "Alice", .age = 30, .email = "alice@example.com" };
    const compact = zjson.stringify(person, .{});
    std.debug.print("person={s}\n", .{compact});

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const pretty = try zjson.stringifyAlloc(person, allocator, .{ .pretty = true, .indent = 2 });
    defer allocator.free(pretty);
    std.debug.print("pretty:\n{s}\n", .{pretty});

    const optional = Person{ .name = "Charlie", .age = 35, .email = null };
    const keep_nulls = try zjson.stringifyAlloc(optional, allocator, .{ .omit_null = false });
    defer allocator.free(keep_nulls);
    std.debug.print("with-null={s}\n", .{keep_nulls});

    const series = [_]i32{ 10, 20, 30 };
    const pretty_array = try zjson.stringifyAlloc(&series, allocator, .{ .pretty = true, .indent = 2 });
    defer allocator.free(pretty_array);
    std.debug.print("array:\n{s}\n", .{pretty_array});
}
