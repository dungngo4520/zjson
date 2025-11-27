const std = @import("std");
const types = @import("types.zig");

pub const Value = types.Value;
pub const Pair = types.Pair;

/// Parse result with arena allocator
pub const ParseResult = struct {
    value: Value,
    arena: std.heap.ArenaAllocator,

    pub fn deinit(self: *ParseResult) void {
        self.arena.deinit();
    }

    /// Copy value to caller's allocator
    pub fn toValue(self: *ParseResult, allocator: std.mem.Allocator) !Value {
        return self.copyValue(self.value, allocator);
    }

    fn copyValue(self: *ParseResult, value: Value, allocator: std.mem.Allocator) error{OutOfMemory}!Value {
        return switch (value) {
            .Null => .Null,
            .Bool => |b| .{ .Bool = b },
            .Number => |n| .{ .Number = try allocator.dupe(u8, n) },
            .String => |s| .{ .String = try allocator.dupe(u8, s) },
            .Array => |arr| {
                const new_arr = try allocator.alloc(Value, arr.len);
                for (arr, 0..) |item, i| {
                    new_arr[i] = try self.copyValue(item, allocator);
                }
                return .{ .Array = new_arr };
            },
            .Object => |obj| {
                const new_obj = try allocator.alloc(Pair, obj.len);
                for (obj, 0..) |pair, i| {
                    new_obj[i] = .{
                        .key = try allocator.dupe(u8, pair.key),
                        .value = try self.copyValue(pair.value, allocator),
                    };
                }
                return .{ .Object = new_obj };
            },
        };
    }
};
