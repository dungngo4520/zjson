const std = @import("std");

pub const HashMapKind = enum {
    none,
    managed,
    unmanaged,
};

pub fn detectStringHashMapKind(comptime T: type) HashMapKind {
    if (@typeInfo(T) != .@"struct") return .none;
    if (comptime isManagedStringHashMap(T)) return .managed;
    if (comptime isUnmanagedStringHashMap(T)) return .unmanaged;
    return .none;
}

pub fn isStringHashMapType(comptime T: type) bool {
    return detectStringHashMapKind(T) != .none;
}

pub fn stringHashMapValueType(comptime MapType: type) type {
    if (!@hasDecl(MapType, "KV")) {
        @compileError("zjson: missing KV declaration for map type " ++ @typeName(MapType));
    }

    const kv_info = @typeInfo(MapType.KV);
    if (kv_info != .@"struct") {
        @compileError("zjson: unexpected KV declaration for " ++ @typeName(MapType));
    }

    inline for (kv_info.@"struct".fields) |field| {
        if (std.mem.eql(u8, field.name, "value")) {
            return field.type;
        }
    }

    @compileError("zjson: value field not found for map type " ++ @typeName(MapType));
}

fn isManagedStringHashMap(comptime T: type) bool {
    if (@typeInfo(T) != .@"struct") return false;
    if (!hasField(T, "unmanaged")) return false;
    if (!hasField(T, "allocator")) return false;
    if (!hasField(T, "ctx")) return false;
    if (getFieldType(T, "ctx") != std.hash_map.StringContext) return false;
    return isUnmanagedStringHashMap(getFieldType(T, "unmanaged"));
}

fn isUnmanagedStringHashMap(comptime T: type) bool {
    if (@typeInfo(T) != .@"struct") return false;
    if (!@hasDecl(T, "KV")) return false;
    if (!hasField(T, "metadata")) return false;
    const kv_info = @typeInfo(T.KV);
    if (kv_info != .@"struct") return false;

    inline for (kv_info.@"struct".fields) |field| {
        if (std.mem.eql(u8, field.name, "key")) {
            return field.type == []const u8;
        }
    }

    return false;
}

fn hasField(comptime T: type, comptime name: []const u8) bool {
    const info = @typeInfo(T);
    if (info != .@"struct") return false;
    inline for (info.@"struct".fields) |field| {
        if (std.mem.eql(u8, field.name, name)) {
            return true;
        }
    }
    return false;
}

fn getFieldType(comptime T: type, comptime name: []const u8) type {
    const info = @typeInfo(T);
    if (info != .@"struct") {
        @compileError("zjson: type " ++ @typeName(T) ++ " is not a struct");
    }
    inline for (info.@"struct".fields) |field| {
        if (std.mem.eql(u8, field.name, name)) {
            return field.type;
        }
    }
    @compileError("zjson: field " ++ name ++ " not found on type " ++ @typeName(T));
}
