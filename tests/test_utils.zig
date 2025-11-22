const std = @import("std");
const zjson = @import("zjson");

pub fn usingAllocator(body: anytype) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    try body(gpa.allocator());
}

pub fn withParsed(
    json: []const u8,
    allocator: std.mem.Allocator,
    options: zjson.ParseOptions,
    body: anytype,
) !void {
    var parsed = try zjson.parse(json, allocator, options);
    defer parsed.deinit();
    try body(parsed.value, allocator);
}
