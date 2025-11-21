const std = @import("std");

pub const Error = error{
    UnexpectedEnd,
    InvalidSyntax,
    InvalidEscape,
    InvalidNumber,
    ExpectedColon,
    ExpectedCommaOrEnd,
    ExpectedValue,
    TrailingCharacters,
    OutOfMemory,
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
};

pub const MarshalOptions = struct {
    pretty: bool = false,
    indent: u32 = 2,
    omit_null: bool = true,
    sort_keys: bool = false,
};

pub const ParseOptions = struct {
    allow_comments: bool = false,
    allow_trailing_commas: bool = false,
};
