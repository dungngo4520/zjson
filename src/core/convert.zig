const std = @import("std");
const types = @import("types.zig");
const errors = @import("errors.zig");

pub const Value = types.Value;
pub const Error = errors.Error;

/// Generic conversion from Value to any supported type
pub fn as(comptime T: type, val: Value) Error!T {
    const info = @typeInfo(T);

    return switch (info) {
        .int => asInt(T, val),
        .float => asFloat(T, val),
        .bool => asBool(val),
        .pointer => |ptr| {
            if (ptr.size == .slice and ptr.child == u8) {
                return asString(val);
            }
            @compileError("Unsupported pointer type: " ++ @typeName(T));
        },
        else => @compileError("Unsupported type for as(): " ++ @typeName(T)),
    };
}

fn asInt(comptime T: type, val: Value) Error!T {
    if (val != .Number) return Error.TypeError;
    const info = @typeInfo(T).int;
    if (info.signedness == .signed) {
        return std.fmt.parseInt(T, val.Number, 10) catch |err| switch (err) {
            error.Overflow => Error.NumberOverflow,
            else => Error.InvalidNumber,
        };
    } else {
        return std.fmt.parseUnsigned(T, val.Number, 10) catch |err| switch (err) {
            error.Overflow => Error.NumberOverflow,
            else => Error.InvalidNumber,
        };
    }
}

fn asFloat(comptime T: type, val: Value) Error!T {
    if (val != .Number) return Error.TypeError;
    return std.fmt.parseFloat(T, val.Number) catch Error.InvalidNumber;
}

fn asBool(val: Value) Error!bool {
    if (val != .Bool) return Error.TypeError;
    return val.Bool;
}

fn asString(val: Value) Error![]const u8 {
    if (val != .String) return Error.TypeError;
    return val.String;
}

pub fn isNull(val: Value) bool {
    return val == .Null;
}

pub fn arrayLen(val: Value) Error!usize {
    if (val != .Array) return Error.TypeError;
    return val.Array.len;
}

pub fn objectLen(val: Value) Error!usize {
    if (val != .Object) return Error.TypeError;
    return val.Object.len;
}

pub fn getField(val: Value, key: []const u8) Error!?Value {
    if (val != .Object) return Error.TypeError;
    for (val.Object) |pair| {
        if (std.mem.eql(u8, pair.key, key)) return pair.value;
    }
    return null;
}

pub fn getIndex(val: Value, index: usize) Error!Value {
    if (val != .Array) return Error.TypeError;
    if (index >= val.Array.len) return Error.IndexOutOfBounds;
    return val.Array[index];
}

pub fn getNumberString(val: Value) Error![]const u8 {
    if (val != .Number) return Error.TypeError;
    return val.Number;
}
