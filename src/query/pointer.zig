const std = @import("std");
const value_mod = @import("../core/value.zig");

pub const Value = value_mod.Value;
pub const Error = value_mod.Error;

/// JSON Pointer error types
pub const PointerError = error{
    InvalidPointer,
    InvalidEscape,
    IndexOutOfBounds,
    NotAnObject,
    KeyNotFound,
};

/// Get a value using JSON Pointer (RFC 6901)
/// Example: "/users/0/name" gets root.users[0].name
pub fn getPointer(value: Value, pointer: []const u8) PointerError!Value {
    if (pointer.len == 0) return value;
    if (pointer[0] != '/') return PointerError.InvalidPointer;

    var current = value;
    var remaining = pointer[1..];

    while (remaining.len > 0) {
        const end = std.mem.indexOfScalar(u8, remaining, '/') orelse remaining.len;
        const token = remaining[0..end];
        const unescaped = try unescapeToken(token);

        current = switch (current) {
            .Object => |obj| blk: {
                for (obj) |pair| {
                    if (std.mem.eql(u8, pair.key, unescaped)) {
                        break :blk pair.value;
                    }
                }
                return PointerError.KeyNotFound;
            },
            .Array => |arr| blk: {
                if (std.mem.eql(u8, unescaped, "-")) {
                    return PointerError.IndexOutOfBounds;
                }
                const index = std.fmt.parseInt(usize, unescaped, 10) catch
                    return PointerError.InvalidPointer;
                if (index >= arr.len) return PointerError.IndexOutOfBounds;
                break :blk arr[index];
            },
            else => return PointerError.NotAnObject,
        };

        remaining = if (end < remaining.len) remaining[end + 1 ..] else "";
    }

    return current;
}

/// Unescape JSON Pointer token (~1 -> /, ~0 -> ~)
fn unescapeToken(token: []const u8) PointerError![]const u8 {
    if (std.mem.indexOfScalar(u8, token, '~') == null) return token;

    const Static = struct {
        threadlocal var buffer: [256]u8 = undefined;
    };

    var i: usize = 0;
    var j: usize = 0;

    while (i < token.len) : (j += 1) {
        if (j >= Static.buffer.len) return PointerError.InvalidPointer;

        if (token[i] == '~') {
            if (i + 1 >= token.len) return PointerError.InvalidEscape;
            Static.buffer[j] = switch (token[i + 1]) {
                '0' => '~',
                '1' => '/',
                else => return PointerError.InvalidEscape,
            };
            i += 2;
        } else {
            Static.buffer[j] = token[i];
            i += 1;
        }
    }

    return Static.buffer[0..j];
}

/// Get pointer and convert to specific type
pub fn getPointerAs(comptime T: type, value: Value, pointer: []const u8) (PointerError || Error)!T {
    const target = try getPointer(value, pointer);
    return switch (T) {
        []const u8 => value_mod.toString(target),
        i64 => value_mod.toI64(target),
        i32 => value_mod.toI32(target),
        u64 => value_mod.toU64(target),
        u32 => value_mod.toU32(target),
        f64 => value_mod.toF64(target),
        f32 => value_mod.toF32(target),
        bool => value_mod.toBool(target),
        else => @compileError("Unsupported type for getPointerAs"),
    };
}

/// Check if a pointer path exists
pub fn hasPointer(value: Value, pointer: []const u8) bool {
    _ = getPointer(value, pointer) catch return false;
    return true;
}
