const std = @import("std");
const zjson = @import("zjson");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try benchmarkNestedArrays(allocator, 50, 100);
    try benchmarkNestedArrays(allocator, 1000, 50);
    try benchmarkNestedObjects(allocator, 50, 100);
    try benchmarkNestedObjects(allocator, 1000, 50);
}

fn benchmarkNestedArrays(allocator: std.mem.Allocator, depth: usize, iterations: usize) !void {
    var json_buf: std.ArrayList(u8) = .empty;
    defer json_buf.deinit(allocator);

    // Create nested arrays: [[[...[1,2,3]...]]]
    for (0..depth) |_| {
        try json_buf.appendSlice(allocator, "[");
    }
    try json_buf.appendSlice(allocator, "1,2,3");
    for (0..depth) |_| {
        try json_buf.appendSlice(allocator, "]");
    }

    const json = json_buf.items;

    // zjson benchmark
    var timer = try std.time.Timer.start();
    for (0..iterations) |_| {
        const value = try zjson.parse(json, allocator, .{});
        zjson.freeValue(value, allocator);
    }
    const zjson_time = timer.read() / iterations / 1000;

    // std.json benchmark
    timer = try std.time.Timer.start();
    for (0..iterations) |_| {
        var parsed = try std.json.parseFromSlice(std.json.Value, allocator, json, .{});
        defer parsed.deinit();
    }
    const std_time = timer.read() / iterations / 1000;

    const speedup = @as(f64, @floatFromInt(std_time)) / @as(f64, @floatFromInt(zjson_time));
    std.debug.print("nested arrays depth={d}: zjson={d}µs std={d}µs speedup={d:.2}x\n", .{ depth, zjson_time, std_time, speedup });
}

fn benchmarkNestedObjects(allocator: std.mem.Allocator, depth: usize, iterations: usize) !void {
    var json_buf: std.ArrayList(u8) = .empty;
    defer json_buf.deinit(allocator);

    // Create nested objects: {"a":{"a":{"a":...{"a":1}}}}
    for (0..depth) |_| {
        try json_buf.appendSlice(allocator, "{\"a\":");
    }
    try json_buf.appendSlice(allocator, "1");
    for (0..depth) |_| {
        try json_buf.appendSlice(allocator, "}");
    }

    const json = json_buf.items;

    // zjson benchmark
    var timer = try std.time.Timer.start();
    for (0..iterations) |_| {
        const value = try zjson.parse(json, allocator, .{});
        zjson.freeValue(value, allocator);
    }
    const zjson_time = timer.read() / iterations / 1000;

    // std.json benchmark
    timer = try std.time.Timer.start();
    for (0..iterations) |_| {
        var parsed = try std.json.parseFromSlice(std.json.Value, allocator, json, .{});
        defer parsed.deinit();
    }
    const std_time = timer.read() / iterations / 1000;

    const speedup = @as(f64, @floatFromInt(std_time)) / @as(f64, @floatFromInt(zjson_time));
    std.debug.print("nested objects depth={d}: zjson={d}µs std={d}µs speedup={d:.2}x\n", .{ depth, zjson_time, std_time, speedup });
}
