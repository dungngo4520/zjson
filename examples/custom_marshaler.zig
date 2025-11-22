const std = @import("std");
const zjson = @import("zjson");

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

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parsed = try zjson.parse("\"#FF5733\"", allocator, .{});
    defer parsed.deinit();

    const color = try zjson.unmarshalWithCustom(Color, parsed.value, allocator);
    std.debug.print("rgb=({d},{d},{d})\n", .{ color.r, color.g, color.b });

    std.debug.print("custom marshal? {}\n", .{comptime zjson.hasCustomMarshal(Color)});
    std.debug.print("custom unmarshal? {}\n", .{comptime zjson.hasCustomUnmarshal(Color)});
}
