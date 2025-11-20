const std = @import("std");
const value_mod = @import("value.zig");

pub const Value = value_mod.Value;
pub const Error = value_mod.Error;

/// Convert a Value to i64
/// Returns error if Value is not a Number or if the string cannot be parsed as i64
pub fn toI64(val: Value) (Error || std.fmt.ParseIntError)!i64 {
    switch (val) {
        .Number => |num_str| {
            return std.fmt.parseInt(i64, num_str, 10) catch return Error.InvalidNumber;
        },
        else => return Error.InvalidNumber,
    }
}

/// Convert a Value to i32
pub fn toI32(val: Value) (Error || std.fmt.ParseIntError)!i32 {
    switch (val) {
        .Number => |num_str| {
            return std.fmt.parseInt(i32, num_str, 10) catch return Error.InvalidNumber;
        },
        else => return Error.InvalidNumber,
    }
}

/// Convert a Value to u64
pub fn toU64(val: Value) (Error || std.fmt.ParseIntError)!u64 {
    switch (val) {
        .Number => |num_str| {
            return std.fmt.parseUnsigned(u64, num_str, 10) catch return Error.InvalidNumber;
        },
        else => return Error.InvalidNumber,
    }
}

/// Convert a Value to u32
pub fn toU32(val: Value) (Error || std.fmt.ParseIntError)!u32 {
    switch (val) {
        .Number => |num_str| {
            return std.fmt.parseUnsigned(u32, num_str, 10) catch return Error.InvalidNumber;
        },
        else => return Error.InvalidNumber,
    }
}

/// Convert a Value to f64
/// Handles parsing of floating point numbers
pub fn toF64(val: Value) (Error || std.fmt.ParseFloatError)!f64 {
    switch (val) {
        .Number => |num_str| {
            return std.fmt.parseFloat(f64, num_str) catch return Error.InvalidNumber;
        },
        else => return Error.InvalidNumber,
    }
}

/// Convert a Value to f32
pub fn toF32(val: Value) (Error || std.fmt.ParseFloatError)!f32 {
    switch (val) {
        .Number => |num_str| {
            return std.fmt.parseFloat(f32, num_str) catch return Error.InvalidNumber;
        },
        else => return Error.InvalidNumber,
    }
}

/// Convert a Value to a string slice
/// Returns error if Value is not a String
pub fn toString(val: Value) Error![]const u8 {
    switch (val) {
        .String => |s| return s,
        .StringOwned => |s| return s,
        else => return Error.InvalidSyntax,
    }
}

/// Convert a Value to bool
/// Returns error if Value is not a Bool
pub fn toBool(val: Value) Error!bool {
    switch (val) {
        .Bool => |b| return b,
        else => return Error.InvalidSyntax,
    }
}

/// Check if a Value is null
pub fn isNull(val: Value) bool {
    return val == .Null;
}

/// Get array length or error if not an array
pub fn arrayLen(val: Value) Error!usize {
    switch (val) {
        .Array => |arr| return arr.len,
        else => return Error.InvalidSyntax,
    }
}

/// Get object field count or error if not an object
pub fn objectLen(val: Value) Error!usize {
    switch (val) {
        .Object => |obj| return obj.len,
        else => return Error.InvalidSyntax,
    }
}

/// Get a field from an object by key
/// Returns null if key not found, error if not an object
pub fn getObjectField(val: Value, key: []const u8) Error!?Value {
    switch (val) {
        .Object => |obj| {
            for (obj) |pair| {
                if (std.mem.eql(u8, pair.key, key)) {
                    return pair.value;
                }
            }
            return null;
        },
        else => return Error.InvalidSyntax,
    }
}

/// Get an array element by index
/// Returns error if not an array or index out of bounds
pub fn getArrayElement(val: Value, index: usize) Error!Value {
    switch (val) {
        .Array => |arr| {
            if (index >= arr.len) return Error.InvalidSyntax;
            return arr[index];
        },
        else => return Error.InvalidSyntax,
    }
}

/// Get raw number string (useful for arbitrary precision)
pub fn getNumberString(val: Value) Error![]const u8 {
    switch (val) {
        .Number => |num_str| return num_str,
        else => return Error.InvalidNumber,
    }
}
