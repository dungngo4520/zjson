const std = @import("std");
const value_mod = @import("value.zig");

pub const Value = value_mod.Value;
pub const Error = value_mod.Error;
pub const Pair = value_mod.Pair;

/// Unmarshal a Value into a target struct type with automatic field mapping
/// Requires the Value to be an Object. Fields are matched by name.
/// Missing fields are left at their zero/default values.
pub fn unmarshal(comptime T: type, val: Value, allocator: std.mem.Allocator) Error!T {
    const type_info = @typeInfo(T);

    if (type_info != .@"struct") {
        return Error.InvalidSyntax;
    }

    if (val != .Object) {
        return Error.InvalidSyntax;
    }

    const obj = val.Object;
    const fields = type_info.@"struct".fields;

    var result: T = undefined;
    var initialized_fields = [_]bool{false} ** fields.len;

    // Iterate over object pairs and match to struct fields
    for (obj) |pair| {
        inline for (fields, 0..) |field, i| {
            if (std.mem.eql(u8, pair.key, field.name)) {
                const field_value = try _unmarshalField(field.type, pair.value, allocator);
                @field(&result, field.name) = field_value;
                initialized_fields[i] = true;
                break;
            }
        }
    }

    // Initialize any uninitialized fields to their zero values
    inline for (fields, 0..) |field, i| {
        if (!initialized_fields[i]) {
            @field(&result, field.name) = @as(field.type, undefined);
            // For optional fields, set to null; for others, set to zero
            if (@typeInfo(field.type) == .optional) {
                @field(&result, field.name) = null;
            }
        }
    }

    return result;
}

/// Internal helper to unmarshal a single field value
fn _unmarshalField(comptime T: type, val: Value, allocator: std.mem.Allocator) Error!T {
    const type_info = @typeInfo(T);

    return switch (type_info) {
        .null, .void => {
            if (val == .Null) return null else return Error.InvalidSyntax;
        },
        .bool => {
            if (val == .Bool) return val.Bool else return Error.InvalidSyntax;
        },
        .int => {
            if (val == .Number) {
                return std.fmt.parseInt(T, val.Number, 10) catch return Error.InvalidNumber;
            }
            return Error.InvalidNumber;
        },
        .float => {
            if (val == .Number) {
                return std.fmt.parseFloat(T, val.Number) catch return Error.InvalidNumber;
            }
            return Error.InvalidNumber;
        },
        .pointer => {
            const ptr_info = type_info.pointer;
            if (ptr_info.child == u8) {
                // String type
                if (val == .String) {
                    return allocator.dupe(u8, val.String) catch return Error.OutOfMemory;
                }
                return Error.InvalidSyntax;
            } else if (ptr_info.size == .slice) {
                // Slice type
                if (val == .Array) {
                    const child_type = ptr_info.child;
                    var array_list = std.ArrayList(child_type).init(allocator);
                    defer array_list.deinit();

                    for (val.Array) |item| {
                        const elem = try _unmarshalField(child_type, item, allocator);
                        try array_list.append(elem);
                    }
                    return try array_list.toOwnedSlice();
                }
                return Error.InvalidSyntax;
            } else {
                // Other pointer types not yet supported
                return Error.InvalidSyntax;
            }
        },
        .optional => {
            if (val == .Null) {
                return null;
            }
            const inner_type = type_info.optional.child;
            const inner_value = try _unmarshalField(inner_type, val, allocator);
            return inner_value;
        },
        .@"struct" => {
            return try unmarshal(T, val, allocator);
        },
        .array => {
            if (val == .Array) {
                const array_info = type_info.array;
                if (val.Array.len != array_info.len) {
                    return Error.InvalidSyntax;
                }
                var result: T = undefined;
                for (val.Array, 0..) |item, i| {
                    result[i] = try _unmarshalField(array_info.child, item, allocator);
                }
                return result;
            }
            return Error.InvalidSyntax;
        },
        .@"enum" => {
            if (val == .String) {
                return std.meta.stringToEnum(T, val.String) orelse return Error.InvalidSyntax;
            }
            return Error.InvalidSyntax;
        },
        else => return Error.InvalidSyntax,
    };
}

/// Helper to safely extract a field from an object and unmarshal it
pub fn getFieldAs(comptime T: type, obj: Value, field_name: []const u8, allocator: std.mem.Allocator) Error!?T {
    if (obj != .Object) return Error.InvalidSyntax;

    for (obj.Object) |pair| {
        if (std.mem.eql(u8, pair.key, field_name)) {
            return try _unmarshalField(T, pair.value, allocator);
        }
    }
    return null;
}

/// Helper to extract all values from an array as a specific type
pub fn arrayAs(comptime T: type, arr: Value, allocator: std.mem.Allocator) Error![]T {
    if (arr != .Array) return Error.InvalidSyntax;

    var result = std.ArrayList(T).init(allocator);
    defer result.deinit();

    for (arr.Array) |item| {
        const elem = try _unmarshalField(T, item, allocator);
        try result.append(elem);
    }

    return try result.toOwnedSlice();
}
