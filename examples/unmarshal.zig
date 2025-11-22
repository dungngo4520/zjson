const std = @import("std");
const zjson = @import("zjson");

const Profile = struct {
    name: []const u8,
    age: u32,
    email: ?[]const u8,
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const json =
        \\{
        \\  "name": "Alice",
        \\  "age": 30,
        \\  "email": "alice@example.com"
        \\}
    ;

    var parsed = try zjson.parse(json, allocator, .{});
    defer parsed.deinit();

    const profile = try zjson.unmarshal(Profile, parsed.value, allocator);
    defer allocator.free(profile.name);
    defer if (profile.email) |email| allocator.free(email);

    const email_text = profile.email orelse "(none)";
    std.debug.print("{s} ({d}) -> {s}\n", .{ profile.name, profile.age, email_text });
}
