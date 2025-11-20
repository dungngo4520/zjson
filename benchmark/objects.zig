const std = @import("std");
const zjson = @import("zjson");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try benchmarkSimpleObjects(allocator, 50, 100);
    try benchmarkSimpleObjects(allocator, 1000, 50);
    try benchmarkManyFields(allocator, 50, 100);
    try benchmarkManyFields(allocator, 1000, 50);
}

fn benchmarkSimpleObjects(allocator: std.mem.Allocator, count: usize, iterations: usize) !void {
    var json_buf: std.ArrayList(u8) = .empty;
    defer json_buf.deinit(allocator);

    try json_buf.appendSlice(allocator, "[");
    for (0..count) |i| {
        if (i > 0) try json_buf.appendSlice(allocator, ",");
        try json_buf.writer(allocator).print("{{\"id\":{d},\"name\":\"obj{d}\",\"value\":42.5}}", .{ i, i });
    }
    try json_buf.appendSlice(allocator, "]");

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
    std.debug.print("{d} objects: zjson={d}µs std={d}µs speedup={d:.2}x\n", .{ count, zjson_time, std_time, speedup });
}

fn benchmarkManyFields(allocator: std.mem.Allocator, field_count: usize, iterations: usize) !void {
    var json_buf: std.ArrayList(u8) = .empty;
    defer json_buf.deinit(allocator);

    try json_buf.appendSlice(allocator, "{");
    for (0..field_count) |i| {
        if (i > 0) try json_buf.appendSlice(allocator, ",");
        try json_buf.writer(allocator).print("\"field{d}\":{d}", .{ i, i * 10 });
    }
    try json_buf.appendSlice(allocator, "}");

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
    std.debug.print("object {d} fields: zjson={d}µs std={d}µs speedup={d:.2}x\n", .{ field_count, zjson_time, std_time, speedup });
}
