const std = @import("std");
const zjson = @import("zjson");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var buffer = std.ArrayList(u8){};
    defer buffer.deinit(allocator);

    var writer = zjson.stream.writer(buffer.writer(allocator), allocator, .{ .pretty = false });
    defer writer.deinit();

    try writer.beginObject();
    try writer.writeField("records");
    try writer.beginArray();

    var i: usize = 0;
    while (i < 1000) : (i += 1) {
        try writer.beginObject();
        try writer.writeField("id");
        try writer.writeInt(i);
        try writer.writeField("value");
        try writer.writeFloat(@as(f64, @floatFromInt(i)) * 1.5);
        try writer.endObject();
    }

    try writer.endArray();
    try writer.endObject();

    std.debug.print("{d}\n", .{buffer.items.len});
}
