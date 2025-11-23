const std = @import("std");
const value_mod = @import("../core/value.zig");
const escape_mod = @import("../utils/escape.zig");
const type_traits = @import("../utils/type_traits.zig");

/// Check if a type has a custom marshal method
pub fn hasCustomMarshal(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .@"struct", .@"union", .@"enum", .@"opaque" => @hasDecl(T, "marshal"),
        else => false,
    };
}

/// Compile-time JSON serialization with options
/// Usage: marshal(value, options)
pub fn marshal(comptime value: anytype, comptime options: value_mod.MarshalOptions) []const u8 {
    return comptime _marshalGeneric(value, options, true, {});
}

/// Runtime JSON serialization with options
pub fn marshalAlloc(value: anytype, allocator: std.mem.Allocator, options: value_mod.MarshalOptions) std.mem.Allocator.Error![]u8 {
    const T = @TypeOf(value);
    if (comptime hasCustomMarshal(T)) {
        const custom_value = value.marshal();
        return marshalAlloc(custom_value, allocator, options);
    }
    return _marshalGeneric(value, options, false, allocator);
}

// Generic marshal handler (works for both compile-time and runtime)
fn _marshalGeneric(value: anytype, options: value_mod.MarshalOptions, comptime is_comptime: bool, allocator: if (is_comptime) void else std.mem.Allocator) if (is_comptime) []const u8 else std.mem.Allocator.Error![]u8 {
    const T = @TypeOf(value);
    const map_kind = comptime type_traits.detectStringHashMapKind(T);
    if (map_kind != .none) {
        if (is_comptime) {
            @compileError("zjson: std.StringHashMap serialization requires marshalAlloc() at runtime");
        }
        return _marshalStringHashMapAlloc(value, allocator, options);
    }
    const list_kind = comptime type_traits.detectArrayListKind(T);
    if (list_kind != .none) {
        if (is_comptime) {
            @compileError("zjson: std.ArrayList serialization requires marshalAlloc() at runtime");
        }
        return _marshalArrayListAlloc(value, allocator, options);
    }
    if (T == value_mod.Value) {
        if (is_comptime) {
            return _marshalValueComptime(value, options);
        } else {
            return _marshalValueAlloc(value, allocator, options);
        }
    }
    const type_info = @typeInfo(T);

    switch (type_info) {
        .bool => {
            const result = if (value) "true" else "false";
            if (is_comptime) return result else return allocator.dupe(u8, result);
        },
        .null, .void => {
            if (is_comptime) return "null" else return allocator.dupe(u8, "null");
        },
        .int, .float, .comptime_int => {
            if (is_comptime) {
                return std.fmt.comptimePrint("{}", .{value});
            } else {
                var buffer = try allocator.alloc(u8, 64);
                const formatted = std.fmt.bufPrint(buffer, "{}", .{value}) catch return buffer;
                const len = formatted.len;
                return allocator.realloc(buffer, len) catch buffer[0..len];
            }
        },
        .@"enum" => {
            const tag_name = @tagName(value);
            if (is_comptime) {
                return escape_mod.escapeStringComptime(tag_name);
            } else {
                return _escapeStringAlloc(tag_name, allocator);
            }
        },
        .optional => {
            if (value) |inner| {
                return _marshalGeneric(inner, options, is_comptime, if (is_comptime) {} else allocator);
            } else {
                if (is_comptime) return "null" else return allocator.dupe(u8, "null");
            }
        },
        .@"struct" => {
            if (is_comptime) {
                return _marshalStructComptime(value, options);
            } else {
                return _marshalStructAlloc(value, allocator, options);
            }
        },
        .array, .vector => {
            if (is_comptime) {
                return _marshalArrayComptime(value, options);
            } else {
                return _marshalArrayAlloc(value, allocator, options);
            }
        },
        .pointer => {
            const ptr_info = type_info.pointer;
            if (ptr_info.child == u8 or (@typeInfo(ptr_info.child) == .array and @typeInfo(ptr_info.child).array.child == u8)) {
                const str: []const u8 = value;
                if (is_comptime) {
                    return escape_mod.escapeStringComptime(str);
                } else {
                    return _escapeStringAlloc(str, allocator);
                }
            } else if (ptr_info.size == .slice or @typeInfo(ptr_info.child) == .array) {
                if (is_comptime) {
                    return _marshalArrayComptime(value, options);
                } else {
                    return _marshalArrayAlloc(value, allocator, options);
                }
            } else {
                @compileError("zjson: unsupported pointer type for marshal: " ++ @typeName(T));
            }
        },
        else => @compileError("zjson: unsupported type for marshal: " ++ @typeName(T)),
    }
}

fn _marshalStructComptime(comptime value: anytype, comptime options: value_mod.MarshalOptions) []const u8 {
    if (options.sort_keys) {
        @compileError("sort_keys is not supported in compile-time marshal(). Use marshalAlloc() for runtime sorting of keys.");
    }

    const T = @TypeOf(value);
    const fields = @typeInfo(T).@"struct".fields;

    comptime var result: []const u8 = "{";
    comptime var first = true;

    inline for (fields) |field| {
        const field_value = @field(value, field.name);
        if (!_shouldSkipFieldChecked(field.type, field_value, options)) {
            const field_json = _marshalGeneric(field_value, options, true, {});
            result = result ++ (if (first) "" else ",") ++ _formatFieldHelper(field.name, field_json, options, true);
            first = false;
        }
    }

    return result ++ (if (options.pretty and !first) "\n" else "") ++ "}";
}

fn _formatFieldHelper(comptime key: []const u8, comptime value: []const u8, comptime options: value_mod.MarshalOptions, comptime is_comptime: bool) if (is_comptime) []const u8 else noreturn {
    if (options.pretty) {
        comptime var result: []const u8 = "\n";
        inline for (0..options.indent) |_| {
            result = result ++ " ";
        }
        result = result ++ escape_mod.escapeStringComptime(key) ++ ": " ++ value;
        return result;
    } else {
        return escape_mod.escapeStringComptime(key) ++ ":" ++ value;
    }
}

fn _shouldSkipField(comptime T: type, comptime value_or_type: anytype) bool {
    return @typeInfo(T) == .optional and value_or_type == null;
}

fn _shouldSkipFieldChecked(comptime T: type, comptime value_or_type: anytype, options: value_mod.MarshalOptions) bool {
    return options.omit_null and _shouldSkipField(T, value_or_type);
}

fn _shouldSkipFieldCheckedRuntime(T: type, field_value: anytype, options: value_mod.MarshalOptions) bool {
    return options.omit_null and @typeInfo(T) == .optional and field_value == null;
}

fn _marshalArrayComptime(comptime value: anytype, comptime options: value_mod.MarshalOptions) []const u8 {
    comptime var result: []const u8 = "[";
    comptime var first = true;

    inline for (value) |item| {
        const item_json = _marshalGeneric(item, options, true, {});
        result = result ++ (if (first) "" else ",") ++ _formatItemComptime(item_json, options);
        first = false;
    }

    return result ++ (if (options.pretty and !first) "\n" else "") ++ "]";
}

fn _formatItemComptime(comptime value: []const u8, comptime options: value_mod.MarshalOptions) []const u8 {
    if (options.pretty) {
        comptime var indent: []const u8 = "\n";
        inline for (0..options.indent) |_| {
            indent = indent ++ " ";
        }
        return indent ++ value;
    } else {
        return value;
    }
}

fn _marshalStructAlloc(value: anytype, allocator: std.mem.Allocator, options: value_mod.MarshalOptions) std.mem.Allocator.Error![]u8 {
    const T = @TypeOf(value);
    const fields = @typeInfo(T).@"struct".fields;

    var buffer = std.array_list.Managed(u8).init(allocator);
    errdefer buffer.deinit();

    try buffer.append('{');
    var first = true;

    // If sort_keys is enabled, collect field names and sort them
    if (options.sort_keys) {
        var field_names: [fields.len][]const u8 = undefined;
        inline for (fields, 0..) |field, i| {
            field_names[i] = field.name;
        }

        std.mem.sort([]const u8, &field_names, {}, struct {
            fn lessThan(_: void, a: []const u8, b: []const u8) bool {
                return std.mem.order(u8, a, b) == .lt;
            }
        }.lessThan);

        for (field_names) |field_name| {
            inline for (fields) |field| {
                if (std.mem.eql(u8, field.name, field_name)) {
                    const field_value = @field(value, field.name);
                    if (!_shouldSkipFieldCheckedRuntime(@TypeOf(field_value), field_value, options)) {
                        const val_str = try _marshalGeneric(field_value, options, false, allocator);
                        defer allocator.free(val_str);
                        try _appendFieldAlloc(&buffer, field.name, val_str, allocator, options, !first);
                        first = false;
                    }
                    break;
                }
            }
        }
    } else {
        inline for (fields) |field| {
            const field_value = @field(value, field.name);
            if (!_shouldSkipFieldCheckedRuntime(@TypeOf(field_value), field_value, options)) {
                const val_str = try _marshalGeneric(field_value, options, false, allocator);
                defer allocator.free(val_str);
                try _appendFieldAlloc(&buffer, field.name, val_str, allocator, options, !first);
                first = false;
            }
        }
    }

    if (options.pretty and !first) {
        try buffer.append('\n');
    }
    try buffer.append('}');
    return buffer.toOwnedSlice();
}

fn _shouldSkipFieldRuntime(comptime T: type, field_value: anytype, options: value_mod.MarshalOptions) bool {
    return options.omit_null and @typeInfo(T) == .optional and field_value == null;
}

fn _appendFieldAlloc(buffer: *std.array_list.Managed(u8), key: []const u8, value: []const u8, allocator: std.mem.Allocator, options: value_mod.MarshalOptions, need_comma: bool) std.mem.Allocator.Error!void {
    if (need_comma) {
        try buffer.append(',');
    }

    if (options.pretty) {
        try buffer.append('\n');
        try _appendIndentAlloc(buffer, options);
    }

    const key_str = try _escapeStringAlloc(key, allocator);
    defer allocator.free(key_str);
    try buffer.appendSlice(key_str);
    try buffer.append(':');

    if (options.pretty) {
        try buffer.append(' ');
    }

    try buffer.appendSlice(value);
}

// Wrapper to maintain API compatibility - allocates and returns escaped string
fn _escapeStringAlloc(s: []const u8, allocator: std.mem.Allocator) std.mem.Allocator.Error![]u8 {
    var buffer = std.ArrayList(u8){};
    errdefer buffer.deinit(allocator);

    try escape_mod.writeEscapedToArrayList(&buffer, allocator, s);
    return buffer.toOwnedSlice(allocator);
}

fn _appendIndentAlloc(buffer: *std.array_list.Managed(u8), options: value_mod.MarshalOptions) std.mem.Allocator.Error!void {
    for (0..options.indent) |_| {
        try buffer.append(' ');
    }
}

fn _marshalArrayAlloc(value: anytype, allocator: std.mem.Allocator, options: value_mod.MarshalOptions) std.mem.Allocator.Error![]u8 {
    var buffer = std.array_list.Managed(u8).init(allocator);
    errdefer buffer.deinit();

    try buffer.append('[');
    var first = true;

    for (value) |item| {
        const item_str = try _marshalGeneric(item, options, false, allocator);
        defer allocator.free(item_str);
        try _appendItemAlloc(&buffer, item_str, options, !first);
        first = false;
    }

    if (options.pretty and !first) {
        try buffer.append('\n');
    }
    try buffer.append(']');
    return buffer.toOwnedSlice();
}

fn _marshalStringHashMapAlloc(value: anytype, allocator: std.mem.Allocator, options: value_mod.MarshalOptions) std.mem.Allocator.Error![]u8 {
    var map = value;
    const MapType = @TypeOf(map);
    const ValueType = type_traits.stringHashMapValueType(MapType);

    var buffer = std.array_list.Managed(u8).init(allocator);
    errdefer buffer.deinit();

    try buffer.append('{');
    var first = true;

    if (options.sort_keys) {
        const EntryRef = struct {
            key: []const u8,
            value_ptr: *const ValueType,
        };

        const count = map.count();
        var entries = try allocator.alloc(EntryRef, count);
        defer allocator.free(entries);

        var filled: usize = 0;
        var iterator = map.iterator();
        while (iterator.next()) |entry| {
            if (filled == entries.len) break;
            entries[filled] = .{
                .key = entry.key_ptr.*,
                .value_ptr = entry.value_ptr,
            };
            filled += 1;
        }

        std.mem.sort(EntryRef, entries[0..filled], {}, struct {
            fn lessThan(_: void, a: EntryRef, b: EntryRef) bool {
                return std.mem.order(u8, a.key, b.key) == .lt;
            }
        }.lessThan);

        for (entries[0..filled]) |entry_ref| {
            const encoded = try _marshalGeneric(entry_ref.value_ptr.*, options, false, allocator);
            defer allocator.free(encoded);
            try _appendFieldAlloc(&buffer, entry_ref.key, encoded, allocator, options, !first);
            first = false;
        }
    } else {
        var iterator = map.iterator();
        while (iterator.next()) |entry| {
            const encoded = try _marshalGeneric(entry.value_ptr.*, options, false, allocator);
            defer allocator.free(encoded);
            try _appendFieldAlloc(&buffer, entry.key_ptr.*, encoded, allocator, options, !first);
            first = false;
        }
    }

    if (options.pretty and !first) {
        try buffer.append('\n');
    }
    try buffer.append('}');
    return buffer.toOwnedSlice();
}

fn _marshalArrayListAlloc(value: anytype, allocator: std.mem.Allocator, options: value_mod.MarshalOptions) std.mem.Allocator.Error![]u8 {
    var buffer = std.array_list.Managed(u8).init(allocator);
    errdefer buffer.deinit();

    try buffer.append('[');
    var first = true;

    for (value.items) |item| {
        const encoded = try _marshalGeneric(item, options, false, allocator);
        defer allocator.free(encoded);
        try _appendItemAlloc(&buffer, encoded, options, !first);
        first = false;
    }

    if (options.pretty and !first) {
        try buffer.append('\n');
    }
    try buffer.append(']');
    return buffer.toOwnedSlice();
}

fn _appendItemAlloc(buffer: *std.array_list.Managed(u8), value: []const u8, options: value_mod.MarshalOptions, need_comma: bool) std.mem.Allocator.Error!void {
    if (need_comma) {
        try buffer.append(',');
    }

    if (options.pretty) {
        try buffer.append('\n');
        try _appendIndentAlloc(buffer, options);
    }

    try buffer.appendSlice(value);
}

fn _marshalValueComptime(comptime value: value_mod.Value, comptime options: value_mod.MarshalOptions) []const u8 {
    return switch (value) {
        .Null => "null",
        .Bool => if (value.Bool) "true" else "false",
        .Number => value.Number,
        .String => escape_mod.escapeStringComptime(value.String),
        .Array => _marshalArrayComptime(value.Array, options),
        .Object => _marshalObjectComptime(value.Object, options),
    };
}

fn _marshalObjectComptime(comptime pairs: []const value_mod.Pair, comptime options: value_mod.MarshalOptions) []const u8 {
    comptime var result: []const u8 = "{";
    comptime var first = true;

    inline for (pairs) |pair| {
        const field_json = _marshalValueComptime(pair.value, options);
        result = result ++ (if (first) "" else ",") ++ _formatFieldHelper(pair.key, field_json, options, true);
        first = false;
    }

    return result ++ (if (options.pretty and !first) "\n" else "") ++ "}";
}

fn _marshalValueAlloc(value: value_mod.Value, allocator: std.mem.Allocator, options: value_mod.MarshalOptions) std.mem.Allocator.Error![]u8 {
    return switch (value) {
        .Null => allocator.dupe(u8, "null"),
        .Bool => allocator.dupe(u8, if (value.Bool) "true" else "false"),
        .Number => allocator.dupe(u8, value.Number),
        .String => _escapeStringAlloc(value.String, allocator),
        .Array => _marshalArrayAlloc(value.Array, allocator, options),
        .Object => _marshalObjectAlloc(value.Object, allocator, options),
    };
}

fn _marshalObjectAlloc(pairs: []const value_mod.Pair, allocator: std.mem.Allocator, options: value_mod.MarshalOptions) std.mem.Allocator.Error![]u8 {
    var buffer = std.array_list.Managed(u8).init(allocator);
    errdefer buffer.deinit();

    try buffer.append('{');
    var first = true;

    for (pairs) |pair| {
        const value_str = try _marshalValueAlloc(pair.value, allocator, options);
        defer allocator.free(value_str);
        try _appendFieldAlloc(&buffer, pair.key, value_str, allocator, options, !first);
        first = false;
    }

    if (options.pretty and !first) {
        try buffer.append('\n');
    }
    try buffer.append('}');
    return buffer.toOwnedSlice();
}
