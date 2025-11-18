const std = @import("std");
const zjson = @import("zjson");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Real-world example: HTTP API response
    const api_response_json =
        \\{
        \\  "status": "success",
        \\  "data": {
        \\    "id": 1,
        \\    "username": "alice_smith",
        \\    "email": "alice@example.com",
        \\    "posts": 42,
        \\    "followers": 128
        \\  },
        \\  "timestamp": "2025-11-19T10:30:00Z"
        \\}
    ;

    std.debug.print("Parsing API response...\n", .{});
    const response = try zjson.parse(api_response_json, allocator);
    defer zjson.freeValue(response, allocator);

    // Extract fields from the response
    const status = response.Object[0];
    std.debug.print("Status: {s}\n", .{status.value.String});

    const data_pair = response.Object[1];
    const data_obj = data_pair.value.Object;

    std.debug.print("User Profile:\n", .{});
    for (data_obj) |pair| {
        switch (pair.value) {
            .String => |s| std.debug.print("  {s}: {s}\n", .{ pair.key, s }),
            .Number => |n| std.debug.print("  {s}: {s}\n", .{ pair.key, n }),
            else => {},
        }
    }

    // Example: Serialize a response
    std.debug.print("\nGenerating response...\n", .{});

    const ApiUser = struct {
        id: u64,
        name: []const u8,
        email: []const u8,
        verified: bool,
    };

    const user = ApiUser{
        .id = 123,
        .name = "Bob Johnson",
        .email = "bob@example.com",
        .verified = true,
    };

    const user_json = zjson.stringify(user);
    std.debug.print("Generated JSON: {s}\n", .{user_json});

    // Example: Round-trip (stringify -> parse)
    std.debug.print("\nRound-trip test...\n", .{});

    const data = .{
        .version = "1.0.0",
        .debug = false,
        .max_retries = 3,
    };

    const stringified = zjson.stringify(data);
    std.debug.print("Stringified: {s}\n", .{stringified});

    const parsed = try zjson.parse(stringified, allocator);
    defer zjson.freeValue(parsed, allocator);

    std.debug.print("Parsed back successfully\n", .{});
    for (parsed.Object) |pair| {
        std.debug.print("  {s}: ", .{pair.key});
        switch (pair.value) {
            .String => |s| std.debug.print("{s}", .{s}),
            .Number => |n| std.debug.print("{s}", .{n}),
            .Bool => |b| std.debug.print("{}", .{b}),
            else => std.debug.print("(other)", .{}),
        }
        std.debug.print("\n", .{});
    }
}
