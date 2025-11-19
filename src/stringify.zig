const std = @import("std");
const value_mod = @import("value.zig");

/// Compile-time JSON serialization with options
/// Usage: stringify(value, options)
pub fn stringify(comptime value: anytype, comptime options: value_mod.StringifyOptions) []const u8 {
    return comptime _stringifyHelper(value, options);
}

/// Runtime JSON serialization with options
pub fn stringifyAlloc(value: anytype, allocator: std.mem.Allocator, options: value_mod.StringifyOptions) std.mem.Allocator.Error![]u8 {
    return _stringifyAllocHelper(value, allocator, options);
}

// Compile-time stringify helpers
fn _stringifyHelper(comptime value: anytype, comptime options: value_mod.StringifyOptions) []const u8 {
    const T = @TypeOf(value);
    if (T == bool) {
        return if (value) "true" else "false";
    } else if (T == void or T == @TypeOf(null)) {
        return "null";
    } else if (T == []const u8) {
        return _escape_string(value);
    } else if (@typeInfo(T) == .pointer) {
        const ptr_info = @typeInfo(T).pointer;
        if (ptr_info.child == u8 or (@typeInfo(ptr_info.child) == .array and @typeInfo(ptr_info.child).array.child == u8)) {
            const str: []const u8 = value;
            return _escape_string(str);
        } else if (ptr_info.size == .slice) {
            return _stringifyArrayComptime(value, options);
        } else if (@typeInfo(ptr_info.child) == .array) {
            return _stringifyArrayComptime(value, options);
        } else {
            @compileError("zjson: unsupported pointer type for stringify: " ++ @typeName(T));
        }
    } else if (T == comptime_int or T == u8 or T == u16 or T == u32 or T == u64 or T == i8 or T == i16 or T == i32 or T == i64 or T == f16 or T == f32 or T == f64) {
        return std.fmt.comptimePrint("{}", .{value});
    } else if (@typeInfo(T) == .@"enum") {
        return _escape_string(@tagName(value));
    } else if (@typeInfo(T) == .optional) {
        if (value) |inner| {
            return _stringifyHelper(inner, options);
        } else {
            return "null";
        }
    } else if (@typeInfo(T) == .@"struct") {
        return _stringifyStructComptime(value, options);
    } else if (@typeInfo(T) == .array or @typeInfo(T) == .vector) {
        return _stringifyArrayComptime(value, options);
    } else {
        @compileError("zjson: unsupported type for stringify: " ++ @typeName(T));
    }
}

fn _stringifyStructComptime(comptime value: anytype, comptime options: value_mod.StringifyOptions) []const u8 {
    const T = @TypeOf(value);
    const fields = @typeInfo(T).@"struct".fields;

    comptime var result: []const u8 = "{";
    comptime var first = true;

    inline for (fields) |field| {
        const field_value = @field(value, field.name);

        // Skip null fields if omit_null is true
        comptime var should_skip = false;
        if (options.omit_null and @typeInfo(field.type) == .optional and field_value == null) {
            should_skip = true;
        }

        if (!should_skip) {
            if (first) {
                first = false;
                if (options.pretty) {
                    result = result ++ "\n";
                    inline for (0..options.indent) |_| {
                        result = result ++ " ";
                    }
                    result = result ++ _escape_string(field.name) ++ ": " ++ _stringifyHelper(field_value, options);
                } else {
                    result = result ++ _escape_string(field.name) ++ ":" ++ _stringifyHelper(field_value, options);
                }
            } else {
                if (options.pretty) {
                    result = result ++ ",\n";
                    inline for (0..options.indent) |_| {
                        result = result ++ " ";
                    }
                    result = result ++ _escape_string(field.name) ++ ": " ++ _stringifyHelper(field_value, options);
                } else {
                    result = result ++ "," ++ _escape_string(field.name) ++ ":" ++ _stringifyHelper(field_value, options);
                }
            }
        }
    }

    if (options.pretty and !first) {
        result = result ++ "\n";
    }
    result = result ++ "}";
    return result;
}
fn _stringifyArrayComptime(comptime value: anytype, comptime options: value_mod.StringifyOptions) []const u8 {
    comptime var result: []const u8 = "[";
    comptime var first = true;

    inline for (value) |item| {
        if (first) {
            first = false;
            if (options.pretty) {
                result = result ++ "\n";
                inline for (0..options.indent) |_| {
                    result = result ++ " ";
                }
            }
            result = result ++ _stringifyHelper(item, options);
        } else {
            if (options.pretty) {
                result = result ++ ",\n";
                inline for (0..options.indent) |_| {
                    result = result ++ " ";
                }
            } else {
                result = result ++ ",";
            }
            result = result ++ _stringifyHelper(item, options);
        }
    }

    if (options.pretty and !first) {
        result = result ++ "\n";
    }
    result = result ++ "]";
    return result;
}

fn _escape_string(s: []const u8) []const u8 {
    comptime var result: []const u8 = "\"";
    inline for (s) |c| {
        switch (c) {
            '"' => result = result ++ "\\\"",
            '\\' => result = result ++ "\\\\",
            '\n' => result = result ++ "\\n",
            '\r' => result = result ++ "\\r",
            '\t' => result = result ++ "\\t",
            '\x08' => result = result ++ "\\b",
            '\x0C' => result = result ++ "\\f",
            '/' => result = result ++ "\\/",
            else => {
                if (c < 0x20) {
                    result = result ++ std.fmt.comptimePrint("\\u{X:0>4}", .{c});
                } else {
                    result = result ++ [_]u8{c};
                }
            },
        }
    }
    result = result ++ "\"";
    return result;
}

// Runtime stringify helpers
fn _stringifyAllocHelper(value: anytype, allocator: std.mem.Allocator, options: value_mod.StringifyOptions) std.mem.Allocator.Error![]u8 {
    const T = @TypeOf(value);

    if (T == bool) {
        return if (value) allocator.dupe(u8, "true") else allocator.dupe(u8, "false");
    } else if (T == void or T == @TypeOf(null)) {
        return allocator.dupe(u8, "null");
    } else if (T == []const u8) {
        return _escapeStringAlloc(value, allocator);
    } else if (@typeInfo(T) == .pointer) {
        const ptr_info = @typeInfo(T).pointer;
        if (ptr_info.child == u8 or (@typeInfo(ptr_info.child) == .array and @typeInfo(ptr_info.child).array.child == u8)) {
            const str: []const u8 = value;
            return _escapeStringAlloc(str, allocator);
        } else if (ptr_info.size == .slice) {
            return _stringifyArrayAlloc(value, allocator, options);
        } else if (@typeInfo(ptr_info.child) == .array) {
            return _stringifyArrayAlloc(value, allocator, options);
        } else {
            @compileError("zjson: unsupported pointer type for stringify: " ++ @typeName(T));
        }
    } else if (T == comptime_int or T == u8 or T == u16 or T == u32 or T == u64 or T == i8 or T == i16 or T == i32 or T == i64 or T == f16 or T == f32 or T == f64) {
        var buffer = try allocator.alloc(u8, 64);
        const formatted = std.fmt.bufPrint(buffer, "{}", .{value}) catch return buffer;
        const len = formatted.len;
        return allocator.realloc(buffer, len) catch buffer[0..len];
    } else if (@typeInfo(T) == .@"enum") {
        return _escapeStringAlloc(@tagName(value), allocator);
    } else if (@typeInfo(T) == .optional) {
        if (value) |inner| {
            return _stringifyAllocHelper(inner, allocator, options);
        } else {
            return allocator.dupe(u8, "null");
        }
    } else if (@typeInfo(T) == .@"struct") {
        return _stringifyStructAlloc(value, allocator, options);
    } else if (@typeInfo(T) == .array) {
        return _stringifyArrayAlloc(value, allocator, options);
    } else {
        @compileError("zjson: unsupported type for stringify: " ++ @typeName(T));
    }
}

fn _stringifyStructAlloc(value: anytype, allocator: std.mem.Allocator, options: value_mod.StringifyOptions) std.mem.Allocator.Error![]u8 {
    const T = @TypeOf(value);
    const fields = @typeInfo(T).@"struct".fields;

    var buffer = std.array_list.Managed(u8).init(allocator);
    errdefer buffer.deinit();

    try buffer.append('{');
    var first = true;

    inline for (fields) |field| {
        const field_value = @field(value, field.name);

        // Skip null fields if omit_null is true
        var should_skip = false;
        if (options.omit_null and @typeInfo(field.type) == .optional and field_value == null) {
            should_skip = true;
        }

        if (!should_skip) {
            if (!first) {
                try buffer.append(',');
            }
            first = false;

            // Add newline and indentation for pretty printing
            if (options.pretty) {
                try buffer.append('\n');
                for (0..options.indent) |_| {
                    try buffer.append(' ');
                }
            }

            const key_str = try _escapeStringAlloc(field.name, allocator);
            defer allocator.free(key_str);
            try buffer.appendSlice(key_str);
            try buffer.append(':');

            if (options.pretty) {
                try buffer.append(' ');
            }

            const val_str = try _stringifyAllocHelper(field_value, allocator, options);
            defer allocator.free(val_str);
            try buffer.appendSlice(val_str);
        }
    }

    if (options.pretty and !first) {
        try buffer.append('\n');
    }

    try buffer.append('}');
    return buffer.toOwnedSlice();
}

fn _stringifyArrayAlloc(value: anytype, allocator: std.mem.Allocator, options: value_mod.StringifyOptions) std.mem.Allocator.Error![]u8 {
    var buffer = std.array_list.Managed(u8).init(allocator);
    errdefer buffer.deinit();

    try buffer.append('[');
    var first = true;

    for (value) |item| {
        if (!first) {
            try buffer.append(',');
        }
        first = false;

        // Add newline and indentation for pretty printing
        if (options.pretty) {
            try buffer.append('\n');
            for (0..options.indent) |_| {
                try buffer.append(' ');
            }
        }

        const item_str = try _stringifyAllocHelper(item, allocator, options);
        defer allocator.free(item_str);
        try buffer.appendSlice(item_str);
    }

    if (options.pretty and !first) {
        try buffer.append('\n');
    }

    try buffer.append(']');
    return buffer.toOwnedSlice();
}

fn _escapeStringAlloc(s: []const u8, allocator: std.mem.Allocator) std.mem.Allocator.Error![]u8 {
    var buffer = std.array_list.Managed(u8).init(allocator);
    errdefer buffer.deinit();

    try buffer.append('"');

    for (s) |c| {
        switch (c) {
            '"' => try buffer.appendSlice("\\\""),
            '\\' => try buffer.appendSlice("\\\\"),
            '\n' => try buffer.appendSlice("\\n"),
            '\r' => try buffer.appendSlice("\\r"),
            '\t' => try buffer.appendSlice("\\t"),
            '\x08' => try buffer.appendSlice("\\b"),
            '\x0C' => try buffer.appendSlice("\\f"),
            '/' => try buffer.appendSlice("\\/"),
            else => {
                if (c < 0x20) {
                    var buf: [6]u8 = undefined;
                    const formatted = std.fmt.bufPrint(&buf, "\\u{X:0>4}", .{c}) catch unreachable;
                    try buffer.appendSlice(formatted);
                } else {
                    try buffer.append(c);
                }
            },
        }
    }

    try buffer.append('"');
    return buffer.toOwnedSlice();
}
