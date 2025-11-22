const std = @import("std");
const value_mod = @import("../core/value.zig");

/// Get the error message for a given Error value
/// Only includes messages for errors defined in value.zig
pub fn getErrorMessage(err: value_mod.Error) []const u8 {
    return switch (err) {
        value_mod.Error.UnexpectedEnd => "Unexpected end of input",
        value_mod.Error.InvalidSyntax => "Invalid syntax",
        value_mod.Error.InvalidEscape => "Invalid escape sequence",
        value_mod.Error.InvalidNumber => "Invalid number",
        value_mod.Error.TrailingCharacters => "Trailing characters",
        value_mod.Error.OutOfMemory => "Out of memory",
        value_mod.Error.MaxDepthExceeded => "Max depth exceeded",
        value_mod.Error.DocumentTooLarge => "Document too large",
        value_mod.Error.DuplicateKey => "Duplicate key",
        value_mod.Error.NumberOverflow => "Number overflow",
    };
}

/// Display a parse error with context and position indicator
pub fn writeParseErrorIndicator(info: value_mod.ParseErrorInfo, writer: anytype) !void {
    const ctx = info.context;
    if (ctx.len == 0) {
        try writer.print("(no context available)\n", .{});
        return;
    }

    const caret_rel = if (info.byte_offset >= info.context_offset)
        info.byte_offset - info.context_offset
    else
        0;

    const before_slice = ctx[0..@min(caret_rel, ctx.len)];
    const line_start = blk: {
        if (std.mem.lastIndexOfScalar(u8, before_slice, '\n')) |idx|
            break :blk idx + 1;
        break :blk 0;
    };

    const line_end = blk: {
        if (caret_rel < ctx.len) {
            if (std.mem.indexOfScalarPos(u8, ctx, caret_rel, '\n')) |idx|
                break :blk idx;
        }
        break :blk ctx.len;
    };

    const line_slice = ctx[line_start..line_end];
    const caret_pos = if (caret_rel > line_start) caret_rel - line_start else 0;

    try writer.print("line {d}, column {d}\n", .{ info.line, info.column });
    try writer.print("{s}\n", .{line_slice});

    var i: usize = 0;
    while (i < caret_pos) : (i += 1) {
        try writer.print(" ", .{});
    }
    try writer.print("^\n", .{});

    if (info.suggested_fix.len > 0) {
        try writer.print("hint: {s}\n", .{info.suggested_fix});
    }
}
