const std = @import("std");
const zjson = @import("zjson");

pub fn main() !void {
    // Example 1: Basic compile-time stringify
    const basic_json = zjson.stringify(.{ .hello = "world" });
    std.debug.print("Basic: {s}\n", .{basic_json});

    // Example 2: Structure
    const Person = struct {
        name: []const u8,
        age: u32,
        email: []const u8,
    };

    const person = Person{
        .name = "Alice",
        .age = 30,
        .email = "alice@example.com",
    };
    const person_json = zjson.stringify(person);
    std.debug.print("Person: {s}\n", .{person_json});

    // Example 3: Arrays
    const numbers = [_]i32{ 1, 2, 3, 4, 5 };
    const array_json = zjson.stringify(&numbers);
    std.debug.print("Array: {s}\n", .{array_json});

    // Example 4: Optional fields
    const User = struct {
        username: []const u8,
        email: ?[]const u8 = null,
        verified: ?bool = null,
    };

    const user1 = User{ .username = "bob", .email = "bob@example.com", .verified = true };
    const user2 = User{ .username = "charlie" };

    std.debug.print("User 1: {s}\n", .{zjson.stringify(user1)});
    std.debug.print("User 2: {s}\n", .{zjson.stringify(user2)});

    // Example 5: Enums
    const Status = enum { active, inactive, pending };
    const status_json = zjson.stringify(Status.active);
    std.debug.print("Status: {s}\n", .{status_json});

    // Example 6: Boolean and numbers
    const flags = .{
        .enabled = true,
        .count = 42,
        .nothing = null,
    };
    std.debug.print("Flags: {s}\n", .{zjson.stringify(flags)});

    // Example 7: String escaping
    const text_with_escapes = "Hello\nWorld\t\"Quoted\"\\ Backslash";
    const escaped_json = zjson.stringify(text_with_escapes);
    std.debug.print("Escaped: {s}\n", .{escaped_json});

    // Example 8: Complex nested structures
    const Address = struct {
        street: []const u8,
        city: []const u8,
        zip: []const u8,
    };

    const Company = struct {
        name: []const u8,
        industry: []const u8,
        employees: u32,
    };

    const Employee = struct {
        id: u32,
        name: []const u8,
        title: []const u8,
        company: Company,
        address: Address,
        active: bool,
    };

    const employee = Employee{
        .id = 1001,
        .name = "Emma Wilson",
        .title = "Senior Engineer",
        .company = Company{
            .name = "TechCorp",
            .industry = "Software",
            .employees = 250,
        },
        .address = Address{
            .street = "123 Main St",
            .city = "San Francisco",
            .zip = "94105",
        },
        .active = true,
    };

    std.debug.print("Complex nested: {s}\n", .{zjson.stringify(employee)});
}
