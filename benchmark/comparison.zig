const std = @import("std");
const zjson = @import("zjson");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("Benchmark: zjson vs std.json\n\n", .{});

    try benchmark_simple_parse(allocator);
    try benchmark_large_array_parse(allocator);
}

fn benchmark_simple_parse(allocator: std.mem.Allocator) !void {
    const json = "{\"name\":\"Alice\",\"age\":30,\"email\":\"alice@example.com\",\"active\":true}";
    const iterations = 100;

    // zjson benchmark
    var timer = try std.time.Timer.start();
    for (0..iterations) |_| {
        const value = try zjson.parse(json, allocator, .{});
        zjson.freeValue(value, allocator);
    }
    const zjson_elapsed = timer.read();
    const zjson_us = (zjson_elapsed / iterations) / 1000;

    // std.json benchmark
    timer = try std.time.Timer.start();
    for (0..iterations) |_| {
        var parsed = try std.json.parseFromSlice(std.json.Value, allocator, json, .{});
        defer parsed.deinit();
    }
    const std_elapsed = timer.read();
    const std_us = (std_elapsed / iterations) / 1000;

    std.debug.print("parse_simple_object:\n", .{});
    std.debug.print("  zjson:    {d}µs/iter\n", .{zjson_us});
    std.debug.print("  std.json: {d}µs/iter\n", .{std_us});
    if (zjson_us < std_us) {
        const faster_pct = ((std_us - zjson_us) * 100) / std_us;
        std.debug.print("  zjson is {d}% faster\n", .{faster_pct});
    } else {
        const faster_pct = ((zjson_us - std_us) * 100) / zjson_us;
        std.debug.print("  std.json is {d}% faster\n", .{faster_pct});
    }
}

fn benchmark_large_array_parse(allocator: std.mem.Allocator) !void {
    var json_buf: std.ArrayList(u8) = .empty;
    defer json_buf.deinit(allocator);

    try json_buf.append(allocator, '[');
    for (0..1000) |i| {
        if (i > 0) try json_buf.append(allocator, ',');
        try json_buf.writer(allocator).print("{d}", .{i});
    }
    try json_buf.append(allocator, ']');

    const json = json_buf.items;
    const iterations = 50;

    // zjson benchmark
    var timer = try std.time.Timer.start();
    for (0..iterations) |_| {
        const value = try zjson.parse(json, allocator, .{});
        zjson.freeValue(value, allocator);
    }
    const zjson_elapsed = timer.read();
    const zjson_us = (zjson_elapsed / iterations) / 1000;

    // std.json benchmark
    timer = try std.time.Timer.start();
    for (0..iterations) |_| {
        var parsed = try std.json.parseFromSlice(std.json.Value, allocator, json, .{});
        defer parsed.deinit();
    }
    const std_elapsed = timer.read();
    const std_us = (std_elapsed / iterations) / 1000;

    std.debug.print("\nparse_large_array (1000 elements):\n", .{});
    std.debug.print("  zjson:    {d}µs/iter\n", .{zjson_us});
    std.debug.print("  std.json: {d}µs/iter\n", .{std_us});
    if (zjson_us < std_us) {
        const faster_pct = ((std_us - zjson_us) * 100) / std_us;
        std.debug.print("  zjson is {d}% faster\n", .{faster_pct});
    } else {
        const faster_pct = ((zjson_us - std_us) * 100) / zjson_us;
        std.debug.print("  std.json is {d}% faster\n", .{faster_pct});
    }
}
