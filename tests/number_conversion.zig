const std = @import("std");
const zjson = @import("zjson");
const test_utils = @import("test_utils.zig");

test "number conversion overflow and boundary" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            // Signed integer overflow
            {
                var parsed = try zjson.parse("9223372036854775808", allocator, .{});
                defer parsed.deinit();
                try std.testing.expectError(zjson.Error.NumberOverflow, zjson.value.as(i64, parsed.value));
            }

            {
                var parsed = try zjson.parse("2147483648", allocator, .{});
                defer parsed.deinit();
                try std.testing.expectError(zjson.Error.NumberOverflow, zjson.value.as(i32, parsed.value));
            }

            // Unsigned integer overflow
            {
                var parsed = try zjson.parse("18446744073709551616", allocator, .{});
                defer parsed.deinit();
                try std.testing.expectError(zjson.Error.NumberOverflow, zjson.value.as(u64, parsed.value));
            }

            {
                var parsed = try zjson.parse("4294967296", allocator, .{});
                defer parsed.deinit();
                try std.testing.expectError(zjson.Error.NumberOverflow, zjson.value.as(u32, parsed.value));
            }

            // Signed integer boundaries (valid)
            {
                var parsed = try zjson.parse("-9223372036854775808", allocator, .{});
                defer parsed.deinit();
                const value = try zjson.value.as(i64, parsed.value);
                try std.testing.expectEqual(@as(i64, -9223372036854775808), value);
            }

            {
                var parsed = try zjson.parse("9223372036854775807", allocator, .{});
                defer parsed.deinit();
                const value = try zjson.value.as(i64, parsed.value);
                try std.testing.expectEqual(@as(i64, 9223372036854775807), value);
            }

            // Unsigned integer boundaries (valid)
            {
                var parsed = try zjson.parse("18446744073709551615", allocator, .{});
                defer parsed.deinit();
                const value = try zjson.value.as(u64, parsed.value);
                try std.testing.expectEqual(@as(u64, 18446744073709551615), value);
            }

            {
                var parsed = try zjson.parse("4294967295", allocator, .{});
                defer parsed.deinit();
                const value = try zjson.value.as(u32, parsed.value);
                try std.testing.expectEqual(@as(u32, 4294967295), value);
            }

            // Float valid
            {
                var parsed = try zjson.parse("1.7976931348623157e+308", allocator, .{});
                defer parsed.deinit();
                const value = try zjson.value.as(f64, parsed.value);
                try std.testing.expect(value > 0);
            }

            {
                var parsed = try zjson.parse("3.4028235e+38", allocator, .{});
                defer parsed.deinit();
                const value = try zjson.value.as(f32, parsed.value);
                try std.testing.expect(value > 0);
            }

            // Type mismatch
            {
                var parsed = try zjson.parse("\"not a number\"", allocator, .{});
                defer parsed.deinit();
                try std.testing.expectError(zjson.Error.TypeError, zjson.value.as(i64, parsed.value));
            }

            // Invalid syntax
            {
                const result = zjson.parse("abc", allocator, .{});
                try std.testing.expectError(zjson.Error.InvalidSyntax, result);
            }
        }
    }.run);
}
