const std = @import("std");
const zjson = @import("zjson");

test "module loads" {
    try std.testing.expect(@TypeOf(zjson) != void);
}
