const std = @import("std");
const zjson = @import("zjson");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const json =
        \\{"users": [
        \\  {"id": 1, "name": "User1"},
        \\  {"id": 2, "name": "User2"},
        \\  {"id": 3, "name": "User3"}
        \\]}
    ;
    var fbs = std.io.fixedBufferStream(json);
    var parser = zjson.streamParser(fbs.reader(), allocator);
    defer parser.deinit();

    var in_users_array = false;
    var user_count: usize = 0;

    while (try parser.next()) |token| {
        defer if (token.allocated) allocator.free(token.data);

        switch (token.type) {
            .field_name => {
                if (std.mem.eql(u8, token.data, "users")) {
                    in_users_array = true;
                }
            },
            .object_begin => {
                if (in_users_array) {
                    user_count += 1;
                }
            },
            else => {},
        }
    }
    std.debug.print("{d}\n", .{user_count});
}
