const std = @import("std");
const zjson = @import("zjson");

pub fn main() !void {
    _ = zjson.stringify(.{ .hello = "world" });
}
