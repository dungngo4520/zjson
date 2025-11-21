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

    std.debug.print("bool={s}\n", .{zjson.marshal(true, .{})});
    std.debug.print("num={s}\n", .{zjson.marshal(42, .{})});
    std.debug.print("str={s}\n", .{zjson.marshal("hello", .{})});
    std.debug.print("enum={s}\n", .{zjson.marshal(Status.active, .{})});
    std.debug.print("array={s}\n", .{zjson.marshal(&array, .{})});

    const person = Person{ .name = "Alice", .age = 30, .email = "alice@example.com" };
    const compact = zjson.marshal(person, .{});
    std.debug.print("person={s}\n", .{compact});

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const pretty = try zjson.marshalAlloc(person, allocator, .{ .pretty = true, .indent = 2 });
    defer allocator.free(pretty);
    std.debug.print("pretty:\n{s}\n", .{pretty});

    const optional = Person{ .name = "Charlie", .age = 35, .email = null };
    const keep_nulls = try zjson.marshalAlloc(optional, allocator, .{ .omit_null = false });
    defer allocator.free(keep_nulls);
    std.debug.print("with-null={s}\n", .{keep_nulls});

    const series = [_]i32{ 10, 20, 30 };
    const pretty_array = try zjson.marshalAlloc(&series, allocator, .{ .pretty = true, .indent = 2 });
    defer allocator.free(pretty_array);
    std.debug.print("array:\n{s}\n", .{pretty_array});
}
