const std = @import("std");

pub const Error = error{
    UnexpectedEnd,
    InvalidSyntax,
    InvalidEscape,
    InvalidNumber,
    TrailingCharacters,
    OutOfMemory,
    MaxDepthExceeded,
    DocumentTooLarge,
    DuplicateKey,
    NumberOverflow,
};

/// Detailed parse error with position information
pub const Value = union(enum) {
    Null,
    Bool: bool,
    Number: []const u8, // Always borrowed from input
    String: []const u8, // Borrowed or owned from arena
    Object: []const Pair,
    Array: []const Value,
};

pub const Pair = struct {
    key: []const u8,
    value: Value,
};

/// Parse result with integrated arena allocator
pub const ParseResult = struct {
    value: Value,
    arena: std.heap.ArenaAllocator,
    error_info: ?ParseErrorInfo = null,

    pub fn deinit(self: *ParseResult) void {
        self.arena.deinit();
    }

    /// Convert to legacy API (copies data to caller's allocator)
    pub fn toValue(self: *ParseResult, allocator: std.mem.Allocator) !Value {
        const copied = try self.copyValue(self.value, allocator);
        return copied;
    }

    fn copyValue(self: *ParseResult, value: Value, allocator: std.mem.Allocator) error{OutOfMemory}!Value {
        return switch (value) {
            .Null => Value.Null,
            .Bool => |b| Value{ .Bool = b },
            .Number => |n| Value{ .Number = try allocator.dupe(u8, n) },
            .String => |s| Value{ .String = try allocator.dupe(u8, s) },
            .Array => |arr| {
                const new_arr = try allocator.alloc(Value, arr.len);
                for (arr, 0..) |item, i| {
                    new_arr[i] = try self.copyValue(item, allocator);
                }
                return Value{ .Array = new_arr };
            },
            .Object => |obj| {
                const new_obj = try allocator.alloc(Pair, obj.len);
                for (obj, 0..) |pair, i| {
                    new_obj[i] = Pair{
                        .key = try allocator.dupe(u8, pair.key),
                        .value = try self.copyValue(pair.value, allocator),
                    };
                }
                return Value{ .Object = new_obj };
            },
        };
    }
};

pub const ParseErrorInfo = struct {
    byte_offset: usize,
    line: usize,
    column: usize,
    context: []const u8 = &.{},
    context_offset: usize = 0,
    suggested_fix: []const u8 = "",
};

pub const MarshalOptions = struct {
    pretty: bool = false,
    indent: u32 = 2,
    omit_null: bool = true,
    sort_keys: bool = false,
};

pub const DuplicateKeyPolicy = enum {
    keep_last,
    keep_first,
    reject,
};

pub const ParseOptions = struct {
    allow_comments: bool = false,
    allow_trailing_commas: bool = false,
    max_depth: usize = 128,
    max_document_size: usize = 10_000_000,
    duplicate_key_policy: DuplicateKeyPolicy = .keep_last,
};

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
