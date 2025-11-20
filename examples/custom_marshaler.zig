const std = @import("std");
const zjson = @import("zjson");

// Define a Color type with custom marshal/unmarshal
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
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse hex color
    const json = "\"#FF5733\"";
    const value = try zjson.parse(json, allocator, .{});
    defer zjson.freeValue(value, allocator);

    // Use custom unmarshal
    const color = try zjson.unmarshalWithCustom(Color, value, allocator);
    std.debug.print("Color: R={d}, G={d}, B={d}\n", .{ color.r, color.g, color.b });

    // Check if type has custom methods
    const has_marshal = comptime zjson.hasCustomMarshal(Color);
    const has_unmarshal = comptime zjson.hasCustomUnmarshal(Color);
    std.debug.print("Has custom marshal: {}\n", .{has_marshal});
    std.debug.print("Has custom unmarshal: {}\n", .{has_unmarshal});
}
