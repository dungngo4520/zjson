const std = @import("std");
const zjson = @import("zjson");
const test_utils = @import("test_utils.zig");

const Color = struct {
    r: u8,
    g: u8,
    b: u8,

    pub fn marshal(self: Color) zjson.Value {
        _ = self;
        return zjson.Value{ .String = "#000000" };
    }

    pub fn unmarshal(val: zjson.Value, alloc: std.mem.Allocator) zjson.Error!Color {
        _ = alloc;
        if (val != .String) return zjson.Error.InvalidSyntax;

        const hex_str = val.String;
        if (hex_str.len != 7 or hex_str[0] != '#') {
            return zjson.Error.InvalidSyntax;
        }

        const r = std.fmt.parseInt(u8, hex_str[1..3], 16) catch return zjson.Error.InvalidNumber;
        const g = std.fmt.parseInt(u8, hex_str[3..5], 16) catch return zjson.Error.InvalidNumber;
        const b = std.fmt.parseInt(u8, hex_str[5..7], 16) catch return zjson.Error.InvalidNumber;

        return Color{ .r = r, .g = g, .b = b };
    }
};

const Point = struct {
    x: i32,
    y: i32,
};

const UUID = struct {
    data: [16]u8,

    pub fn marshal(self: UUID) zjson.Value {
        _ = self;
        return zjson.Value{ .String = "00000000-0000-0000-0000-000000000000" };
    }

    pub fn unmarshal(val: zjson.Value, alloc: std.mem.Allocator) zjson.Error!UUID {
        _ = alloc;
        if (val != .String) return zjson.Error.InvalidSyntax;

        const uuid_str = val.String;
        if (uuid_str.len != 36) {
            return zjson.Error.InvalidSyntax;
        }

        var data: [16]u8 = undefined;
        // Simple parsing: just copy bytes as-is for testing
        if (uuid_str.len >= 2) {
            data[0] = 0xAB;
        }

        return UUID{ .data = data };
    }
};

test "detect custom marshal method" {
    const has_custom = comptime zjson.hasCustomMarshal(Color);
    try std.testing.expect(has_custom);
}

test "detect custom unmarshal method" {
    const has_custom = comptime zjson.hasCustomUnmarshal(Color);
    try std.testing.expect(has_custom);
}

test "unmarshal hex colors" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            var single = try zjson.parseToArena("\"#FF5733\"", allocator, .{});
            defer single.deinit();
            const color = try zjson.unmarshalWithCustom(Color, single.value, allocator);
            try std.testing.expect(color.r == 0xFF and color.g == 0x57 and color.b == 0x33);

            const colors = [_]struct { json: []const u8, r: u8, g: u8, b: u8 }{
                .{ .json = "\"#000000\"", .r = 0x00, .g = 0x00, .b = 0x00 },
                .{ .json = "\"#FFFFFF\"", .r = 0xFF, .g = 0xFF, .b = 0xFF },
                .{ .json = "\"#FF0000\"", .r = 0xFF, .g = 0x00, .b = 0x00 },
                .{ .json = "\"#00FF00\"", .r = 0x00, .g = 0xFF, .b = 0x00 },
            };

            inline for (colors) |test_color| {
                var value = try zjson.parseToArena(test_color.json, allocator, .{});
                defer value.deinit();
                const parsed = try zjson.unmarshalWithCustom(Color, value.value, allocator);
                try std.testing.expect(parsed.r == test_color.r);
                try std.testing.expect(parsed.g == test_color.g);
                try std.testing.expect(parsed.b == test_color.b);
            }
        }
    }.run);
}

test "type without custom marshal" {
    const has_custom = comptime zjson.hasCustomMarshal(Point);
    try std.testing.expect(!has_custom);
}

test "type without custom unmarshal" {
    const has_custom = comptime zjson.hasCustomUnmarshal(Point);
    try std.testing.expect(!has_custom);
}

test "UUID custom unmarshal" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            var value = try zjson.parseToArena("\"123e4567-e89b-12d3-a456-426614174000\"", allocator, .{});
            defer value.deinit();
            const uuid = try zjson.unmarshalWithCustom(UUID, value.value, allocator);
            try std.testing.expect(uuid.data[0] == 0xAB);
        }
    }.run);
}

test "invalid hex color error handling" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            var value = try zjson.parseToArena("\"INVALID\"", allocator, .{});
            defer value.deinit();
            const result = zjson.unmarshalWithCustom(Color, value.value, allocator);
            try std.testing.expectError(zjson.Error.InvalidSyntax, result);
        }
    }.run);
}

test "mixed types with custom and non-custom" {
    const has_color_custom = comptime zjson.hasCustomMarshal(Color);
    const has_point_custom = comptime zjson.hasCustomMarshal(Point);

    try std.testing.expect(has_color_custom);
    try std.testing.expect(!has_point_custom);
}

test "verify marshal method signature" {
    const color = Color{ .r = 255, .g = 128, .b = 0 };
    const value = color.marshal();

    try std.testing.expect(value == .String);
}
