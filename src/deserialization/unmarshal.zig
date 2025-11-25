const std = @import("std");
const value_mod = @import("../core/value.zig");
const type_traits = @import("../utils/type_traits.zig");

pub const Value = value_mod.Value;
pub const Error = value_mod.Error;
pub const Pair = value_mod.Pair;

/// Check if a type has a custom unmarshal method
pub fn hasCustomUnmarshal(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .@"struct", .@"union", .@"enum", .@"opaque" => @hasDecl(T, "unmarshal"),
        else => false,
    };
}

/// Unmarshal a Value into a target type (struct, slice, array, or primitive)
/// For structs: Requires the Value to be an Object. Fields are matched by name.
/// For slices/arrays: Requires the Value to be an Array.
pub fn unmarshal(comptime T: type, val: Value, allocator: std.mem.Allocator) Error!T {
    if (comptime hasCustomUnmarshal(T)) {
        return T.unmarshal(val, allocator);
    }
    if (comptime type_traits.isStringHashMapType(T)) {
        return try _unmarshalStringHashMap(T, val, allocator);
    }
    if (comptime type_traits.isArrayListType(T)) {
        return try _unmarshalArrayList(T, val, allocator);
    }
    const type_info = @typeInfo(T);

    return switch (type_info) {
        .@"struct" => {
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
        },
        .pointer => {
            const ptr_info = type_info.pointer;
            if (ptr_info.size == .slice) {
                // Handle slice types like []i32, [][]const u8, etc.
                if (val != .Array) {
                    return Error.InvalidSyntax;
                }

                const child_type = ptr_info.child;
                const items = try allocator.alloc(child_type, val.Array.len);

                for (val.Array, 0..) |item, i| {
                    const elem = try _unmarshalField(child_type, item, allocator);
                    items[i] = elem;
                }

                return items;
            } else {
                return Error.InvalidSyntax;
            }
        },
        .array => {
            // Handle fixed-size arrays like [5]i32
            if (val != .Array) {
                return Error.InvalidSyntax;
            }

            const array_info = type_info.array;
            if (val.Array.len != array_info.len) {
                return Error.InvalidSyntax;
            }

            var result: T = undefined;
            for (val.Array, 0..) |item, i| {
                result[i] = try _unmarshalField(array_info.child, item, allocator);
            }

            return result;
        },
        else => {
            // For primitives and other types, delegate to _unmarshalField
            return try _unmarshalField(T, val, allocator);
        },
    };
}

/// Internal helper to unmarshal a single field value
fn _unmarshalField(comptime T: type, val: Value, allocator: std.mem.Allocator) Error!T {
    // Check for custom unmarshal first (for all types including enums)
    if (comptime hasCustomUnmarshal(T)) {
        return T.unmarshal(val, allocator);
    }

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
                    const items = try allocator.alloc(child_type, val.Array.len);

                    for (val.Array, 0..) |item, i| {
                        const elem = try _unmarshalField(child_type, item, allocator);
                        items[i] = elem;
                    }
                    return items;
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

fn _unmarshalStringHashMap(comptime MapType: type, val: Value, allocator: std.mem.Allocator) Error!MapType {
    if (val != .Object) return Error.InvalidSyntax;

    var map = _stringHashMapInit(MapType, allocator);
    errdefer _stringHashMapDeinit(&map, allocator);

    try _stringHashMapEnsureCapacity(&map, allocator, val.Object.len);

    const ValueType = type_traits.stringHashMapValueType(MapType);

    for (val.Object) |pair| {
        const key_copy = allocator.dupe(u8, pair.key) catch return Error.OutOfMemory;
        var key_owned = true;
        defer if (key_owned) allocator.free(key_copy);

        const decoded = try _unmarshalField(ValueType, pair.value, allocator);
        try _stringHashMapPut(&map, allocator, key_copy, decoded);
        key_owned = false;
    }

    return map;
}

fn _unmarshalArrayList(comptime ListType: type, val: Value, allocator: std.mem.Allocator) Error!ListType {
    if (val != .Array) return Error.InvalidSyntax;

    var list = try _arrayListInit(ListType, allocator, val.Array.len);
    errdefer _arrayListDeinit(ListType, &list, allocator);

    const ValueType = type_traits.arrayListValueType(ListType);
    for (val.Array) |item| {
        const decoded = try _unmarshalField(ValueType, item, allocator);
        try _arrayListAppend(ListType, &list, allocator, decoded);
    }

    return list;
}

fn _arrayListInit(comptime ListType: type, allocator: std.mem.Allocator, capacity: usize) Error!ListType {
    return ListType.initCapacity(allocator, capacity);
}

fn _arrayListDeinit(comptime ListType: type, list: *ListType, allocator: std.mem.Allocator) void {
    const kind = comptime type_traits.detectArrayListKind(ListType);
    switch (kind) {
        .managed => list.deinit(),
        .unmanaged => list.deinit(allocator),
        .none => unreachable,
    }
}

fn _arrayListAppend(comptime ListType: type, list: *ListType, allocator: std.mem.Allocator, value: anytype) Error!void {
    const kind = comptime type_traits.detectArrayListKind(ListType);
    switch (kind) {
        .managed => try list.append(value),
        .unmanaged => try list.append(allocator, value),
        .none => unreachable,
    }
}

fn _stringHashMapInit(comptime MapType: type, allocator: std.mem.Allocator) MapType {
    const kind = comptime type_traits.detectStringHashMapKind(MapType);
    if (kind == .managed) {
        return MapType.init(allocator);
    } else if (kind == .unmanaged) {
        return MapType{};
    } else {
        unreachable;
    }
}

fn _stringHashMapDeinit(map: anytype, allocator: std.mem.Allocator) void {
    const MapType = @TypeOf(map.*);
    const kind = comptime type_traits.detectStringHashMapKind(MapType);
    if (kind == .managed) {
        map.deinit();
    } else if (kind == .unmanaged) {
        map.deinit(allocator);
    } else {
        unreachable;
    }
}

fn _stringHashMapEnsureCapacity(map: anytype, allocator: std.mem.Allocator, needed: usize) Error!void {
    if (needed == 0) return;
    const MapType = @TypeOf(map.*);
    const desired = std.math.cast(u32, needed) orelse return Error.OutOfMemory;
    const kind = comptime type_traits.detectStringHashMapKind(MapType);
    if (kind == .managed) {
        map.ensureTotalCapacity(desired) catch |err| switch (err) {
            error.OutOfMemory => return Error.OutOfMemory,
            else => return err,
        };
    } else if (kind == .unmanaged) {
        map.ensureTotalCapacity(allocator, desired) catch |err| switch (err) {
            error.OutOfMemory => return Error.OutOfMemory,
            else => return err,
        };
    } else {
        unreachable;
    }
}

fn _stringHashMapPut(map: anytype, allocator: std.mem.Allocator, key: []const u8, value: anytype) Error!void {
    const MapType = @TypeOf(map.*);
    const kind = comptime type_traits.detectStringHashMapKind(MapType);
    if (kind == .managed) {
        map.put(key, value) catch |err| switch (err) {
            error.OutOfMemory => return Error.OutOfMemory,
            else => return err,
        };
    } else if (kind == .unmanaged) {
        map.put(allocator, key, value) catch |err| switch (err) {
            error.OutOfMemory => return Error.OutOfMemory,
            else => return err,
        };
    } else {
        unreachable;
    }
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

    const result = try allocator.alloc(T, arr.Array.len);

    for (arr.Array, 0..) |item, i| {
        const elem = try _unmarshalField(T, item, allocator);
        result[i] = elem;
    }

    return result;
}
