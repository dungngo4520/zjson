const std = @import("std");
const zjson = @import("zjson");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const bad_json = 
        \\{
        \\  "users": [
        \\    {"name": "Alice", "age": 30},
        \\    {"name": "Bob", "age": 25},
        \\  ],
        \\  "count": 2,
        \\}
    ;

    var parsed = zjson.parseToArena(bad_json, allocator, .{}) catch |err| {
        std.debug.print("Parse failed: {}\n", .{err});
        if (zjson.lastParseErrorInfo()) |info| {
            std.debug.print(
                "byte offset={d}, line={d}, column={d}\n",
                .{ info.byte_offset, info.line, info.column },
            );
            var stderr_buffer: [256]u8 = undefined;
            var stderr_writer = std.fs.File.stderr().writer(&stderr_buffer);
            const stderr: *std.Io.Writer = &stderr_writer.interface;
            try zjson.writeParseErrorIndicator(info, stderr);
            try stderr.flush();
        } else {
            std.debug.print("No extra error info available\n", .{});
        }
        return;
    };

    defer parsed.deinit();
    std.debug.print("Unexpected success, parsed tag={s}\n", .{@tagName(parsed.value)});
}
