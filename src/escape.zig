const std = @import("std");

/// Writes an escaped JSON string (including surrounding quotes) to an ArrayList.
/// This is optimized for ArrayList with appendSlice operations.
pub fn writeEscapedToArrayList(buffer: *std.ArrayList(u8), allocator: std.mem.Allocator, value: []const u8) std.mem.Allocator.Error!void {
    try buffer.append(allocator, '"');

    for (value) |c| {
        switch (c) {
            '"' => try buffer.appendSlice(allocator, "\\\""),
            '\\' => try buffer.appendSlice(allocator, "\\\\"),
            '\n' => try buffer.appendSlice(allocator, "\\n"),
            '\r' => try buffer.appendSlice(allocator, "\\r"),
            '\t' => try buffer.appendSlice(allocator, "\\t"),
            '\x08' => try buffer.appendSlice(allocator, "\\b"),
            '\x0C' => try buffer.appendSlice(allocator, "\\f"),
            '/' => try buffer.appendSlice(allocator, "\\/"),
            else => {
                if (c < 0x20) {
                    var buf: [6]u8 = undefined;
                    const formatted = std.fmt.bufPrint(&buf, "\\u{X:0>4}", .{c}) catch unreachable;
                    try buffer.appendSlice(allocator, formatted);
                } else {
                    try buffer.append(allocator, c);
                }
            },
        }
    }

    try buffer.append(allocator, '"');
}

/// Writes an escaped JSON string (including surrounding quotes) to any Writer.
/// This is optimized for Writer interface with writeAll operations.
pub fn writeEscapedToWriter(writer: anytype, value: []const u8) @TypeOf(writer).Error!void {
    try writer.writeByte('"');

    for (value) |c| {
        switch (c) {
            '"' => try writer.writeAll("\\\""),
            '\\' => try writer.writeAll("\\\\"),
            '\n' => try writer.writeAll("\\n"),
            '\r' => try writer.writeAll("\\r"),
            '\t' => try writer.writeAll("\\t"),
            '\x08' => try writer.writeAll("\\b"),
            '\x0C' => try writer.writeAll("\\f"),
            '/' => try writer.writeAll("\\/"),
            0x00...0x07, 0x0B, 0x0E...0x1F => try std.fmt.format(writer, "\\u{x:0>4}", .{c}),
            else => try writer.writeByte(c),
        }
    }

    try writer.writeByte('"');
}

/// Comptime version: escapes a string at compile time, returning a comptime string slice.
/// This is used for comptime-known strings in marshal.zig.
pub fn escapeStringComptime(comptime s: []const u8) []const u8 {
    comptime var result: []const u8 = "\"";
    inline for (s) |c| {
        result = result ++ escapeCharComptime(c);
    }
    result = result ++ "\"";
    return result;
}

/// Comptime version: escapes a single character at compile time.
pub fn escapeCharComptime(comptime c: u8) []const u8 {
    return switch (c) {
        '"' => "\\\"",
        '\\' => "\\\\",
        '\n' => "\\n",
        '\r' => "\\r",
        '\t' => "\\t",
        '\x08' => "\\b",
        '\x0C' => "\\f",
        '/' => "\\/",
        else => if (c < 0x20) std.fmt.comptimePrint("\\u{X:0>4}", .{c}) else &[_]u8{c},
    };
}
