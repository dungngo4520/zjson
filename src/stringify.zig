const std = @import("std");

/// Compile-time JSON serialization for Zig structs and values
pub fn stringify(comptime value: anytype) []const u8 {
    return comptime _stringifyHelper(value);
}

/// Runtime JSON serialization requiring an allocator
pub fn stringifyAlloc(value: anytype, allocator: std.mem.Allocator) std.mem.Allocator.Error![]u8 {
    return _stringifyAllocHelper(value, allocator);
}

// Compile-time stringify helpers
fn _stringifyHelper(comptime value: anytype) []const u8 {
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
            return _stringifyArray(value);
        } else if (@typeInfo(ptr_info.child) == .array) {
            return _stringifyArray(value);
        } else {
            @compileError("zjson: unsupported pointer type for stringify: " ++ @typeName(T));
        }
    } else if (T == comptime_int or T == u8 or T == u16 or T == u32 or T == u64 or T == i8 or T == i16 or T == i32 or T == i64 or T == f16 or T == f32 or T == f64) {
        return std.fmt.comptimePrint("{}", .{value});
    } else if (@typeInfo(T) == .@"enum") {
        return _escape_string(@tagName(value));
    } else if (@typeInfo(T) == .optional) {
        if (value) |inner| {
            return _stringifyHelper(inner);
        } else {
            return "null";
        }
    } else if (@typeInfo(T) == .@"struct") {
        return _stringifyStruct(value);
    } else if (@typeInfo(T) == .array or @typeInfo(T) == .vector) {
        return _stringifyArray(value);
    } else {
        @compileError("zjson: unsupported type for stringify: " ++ @typeName(T));
    }
}

fn _stringifyStruct(comptime value: anytype) []const u8 {
    const T = @TypeOf(value);
    const fields = @typeInfo(T).@"struct".fields;

    comptime var result: []const u8 = "{";
    comptime var first = true;

    inline for (fields) |field| {
        const field_value = @field(value, field.name);

        if (@typeInfo(field.type) == .optional and field_value == null) {
            continue;
        }

        if (first) {
            first = false;
            result = result ++ _escape_string(field.name) ++ ":" ++ _stringifyHelper(field_value);
        } else {
            result = result ++ "," ++ _escape_string(field.name) ++ ":" ++ _stringifyHelper(field_value);
        }
    }
    result = result ++ "}";
    return result;
}

fn _stringifyArray(comptime value: anytype) []const u8 {
    comptime var result: []const u8 = "[";
    comptime var first = true;

    inline for (value) |item| {
        if (first) {
            first = false;
            result = result ++ _stringifyHelper(item);
        } else {
            result = result ++ "," ++ _stringifyHelper(item);
        }
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
fn _stringifyAllocHelper(value: anytype, allocator: std.mem.Allocator) std.mem.Allocator.Error![]u8 {
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
            return _stringifyArrayAlloc(value, allocator);
        } else if (@typeInfo(ptr_info.child) == .array) {
            return _stringifyArrayAlloc(value, allocator);
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
            return _stringifyAllocHelper(inner, allocator);
        } else {
            return allocator.dupe(u8, "null");
        }
    } else if (@typeInfo(T) == .@"struct") {
        return _stringifyStructAlloc(value, allocator);
    } else if (@typeInfo(T) == .array) {
        return _stringifyArrayAlloc(value, allocator);
    } else {
        @compileError("zjson: unsupported type for stringify: " ++ @typeName(T));
    }
}

fn _stringifyStructAlloc(value: anytype, allocator: std.mem.Allocator) std.mem.Allocator.Error![]u8 {
    const T = @TypeOf(value);
    const fields = @typeInfo(T).@"struct".fields;

    var buffer = std.array_list.Managed(u8).init(allocator);
    errdefer buffer.deinit();

    try buffer.append('{');
    var first = true;

    inline for (fields) |field| {
        const field_value = @field(value, field.name);

        const should_skip = @typeInfo(field.type) == .optional and field_value == null;
        if (!should_skip) {
            if (!first) {
                try buffer.append(',');
            }
            first = false;

            const key_str = try _escapeStringAlloc(field.name, allocator);
            defer allocator.free(key_str);
            try buffer.appendSlice(key_str);
            try buffer.append(':');

            const val_str = try _stringifyAllocHelper(field_value, allocator);
            defer allocator.free(val_str);
            try buffer.appendSlice(val_str);
        }
    }

    try buffer.append('}');
    return buffer.toOwnedSlice();
}

fn _stringifyArrayAlloc(value: anytype, allocator: std.mem.Allocator) std.mem.Allocator.Error![]u8 {
    var buffer = std.array_list.Managed(u8).init(allocator);
    errdefer buffer.deinit();

    try buffer.append('[');
    var first = true;

    for (value) |item| {
        if (!first) {
            try buffer.append(',');
        }
        first = false;

        const item_str = try _stringifyAllocHelper(item, allocator);
        defer allocator.free(item_str);
        try buffer.appendSlice(item_str);
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
