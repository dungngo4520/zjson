const std = @import("std");
const zjson = @import("zjson");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Define a Person struct
    const Person = struct {
        name: []const u8,
        age: u32,
        email: ?[]const u8,
    };

    // Parse JSON into a Value
    const json = 
        \\{
        \\  "name": "Alice",
        \\  "age": 30,
        \\  "email": "alice@example.com"
        \\}
    ;
    const value = try zjson.parse(json, allocator, .{});
    defer zjson.freeValue(value, allocator);

    // Unmarshal Value into Person struct
    const person = try zjson.unmarshal(Person, value, allocator);
    defer allocator.free(person.name);
    if (person.email) |email| {
        defer allocator.free(email);
        std.debug.print("Name: {s}, Age: {d}, Email: {s}\n", .{ person.name, person.age, email });
    }
}
