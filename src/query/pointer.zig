const std = @import("std");
const value_mod = @import("../core/value.zig");

pub const Value = value_mod.Value;
pub const Error = value_mod.Error;

/// Get a value using JSON Pointer
/// Example: "/users/0/name" gets root.users[0].name
pub fn getPointer(value: Value, pointer: []const u8) Error!Value {
    if (pointer.len == 0) return value;
    if (pointer[0] != '/') return Error.InvalidPath;

    var current = value;
    var remaining = pointer[1..];

    while (remaining.len > 0) {
        const end = std.mem.indexOfScalar(u8, remaining, '/') orelse remaining.len;
        const token = remaining[0..end];

        current = switch (current) {
            .Object => |obj| blk: {
                for (obj) |pair| {
                    if (try tokenMatchesKey(token, pair.key)) {
                        break :blk pair.value;
                    }
                }
                return Error.KeyNotFound;
            },
            .Array => |arr| blk: {
                if (std.mem.eql(u8, token, "-")) {
                    return Error.IndexOutOfBounds;
                }
                const index = std.fmt.parseInt(usize, token, 10) catch
                    return Error.InvalidPath;
                if (index >= arr.len) return Error.IndexOutOfBounds;
                break :blk arr[index];
            },
            else => return Error.TypeError,
        };

        remaining = if (end < remaining.len) remaining[end + 1 ..] else "";
    }

    return current;
}

/// Compare escaped token with unescaped key
/// Token uses JSON Pointer escaping: ~0 = ~, ~1 = /
fn tokenMatchesKey(token: []const u8, key: []const u8) Error!bool {
    var ti: usize = 0;
    var ki: usize = 0;

    while (ti < token.len and ki < key.len) {
        if (token[ti] == '~') {
            if (ti + 1 >= token.len) return Error.InvalidEscape;
            const unescaped: u8 = switch (token[ti + 1]) {
                '0' => '~',
                '1' => '/',
                else => return Error.InvalidEscape,
            };
            if (key[ki] != unescaped) return false;
            ti += 2;
            ki += 1;
        } else {
            if (token[ti] != key[ki]) return false;
            ti += 1;
            ki += 1;
        }
    }

    // Both must be fully consumed for a match
    return ti == token.len and ki == key.len;
}

/// Get pointer and convert to specific type
pub fn getPointerAs(comptime T: type, value: Value, pointer: []const u8) Error!T {
    const target = try getPointer(value, pointer);
    return value_mod.as(T, target);
}

/// Check if a pointer path exists
pub fn hasPointer(value: Value, pointer: []const u8) bool {
    _ = getPointer(value, pointer) catch return false;
    return true;
}
