const std = @import("std");
const zjson = @import("zjson");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try benchmark(allocator, 100, 100);
    try benchmark(allocator, 10000, 10);
    try benchmark(allocator, 1000000, 1);
}

fn benchmark(allocator: std.mem.Allocator, count: usize, iterations: usize) !void {
    var json_buf: std.ArrayList(u8) = .empty;
    defer json_buf.deinit(allocator);

    try json_buf.appendSlice(allocator, "[");
    for (0..count) |i| {
        if (i > 0) try json_buf.appendSlice(allocator, ",");
        try json_buf.writer(allocator).print("\"string_value_{d}\"", .{i});
    }
    try json_buf.appendSlice(allocator, "]");

    const json = json_buf.items;
    const result = try compare(json, allocator, iterations);
    const speedup = @as(f64, @floatFromInt(result.stdlib)) / @as(f64, @floatFromInt(result.zjson));
    std.debug.print("{d} strings: zjson={d}µs std={d}µs speedup={d:.2}x\n", .{ count, result.zjson, result.stdlib, speedup });
}

const BenchmarkResult = struct {
    zjson: u64,
    stdlib: u64,
};

fn compare(json: []const u8, allocator: std.mem.Allocator, iterations: usize) !BenchmarkResult {
    var timer = try std.time.Timer.start();
    for (0..iterations) |_| {
        var parsed = try zjson.parse(json, allocator, .{});
        parsed.deinit();
    }
    const zjson_time = timer.read() / iterations / 1000;

    timer = try std.time.Timer.start();
    for (0..iterations) |_| {
        var parsed = try std.json.parseFromSlice(std.json.Value, allocator, json, .{});
        defer parsed.deinit();
    }
    const std_time = timer.read() / iterations / 1000;

    return BenchmarkResult{ .zjson = zjson_time, .stdlib = std_time };
}
