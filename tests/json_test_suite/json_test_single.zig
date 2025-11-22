const std = @import("std");
const zjson = @import("zjson");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != 2) {
        std.debug.print("Usage: {s} <json_file>\n", .{args[0]});
        return error.InvalidArgs;
    }

    const filepath = args[1];

    // Read file content
    const file = try std.fs.cwd().openFile(filepath, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 10 * 1024 * 1024); // 10MB max
    defer allocator.free(content);

    // Try to parse
    var parse_result = zjson.parseToArena(content, allocator, .{}) catch |err| {
        std.debug.print("REJECTED: {}\n", .{err});
        return;
    };

    parse_result.deinit();
    std.debug.print("ACCEPTED\n", .{});
}
