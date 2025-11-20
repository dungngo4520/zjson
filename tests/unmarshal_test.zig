const std = @import("std");
const zjson = @import("zjson");

test "unmarshal simple struct with primitives" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const Person = struct {
        name: []const u8,
        age: u32,
    };

    const json = "{\"name\":\"Bob\",\"age\":25}";
    const value = try zjson.parse(json, allocator, .{});
    defer zjson.freeValue(value, allocator);

    const person = try zjson.unmarshal(Person, value, allocator);
    defer allocator.free(person.name);

    try std.testing.expect(std.mem.eql(u8, person.name, "Bob"));
    try std.testing.expect(person.age == 25);
}

test "unmarshal struct with optional fields" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const User = struct {
        username: []const u8,
        bio: ?[]const u8,
    };

    // Test with bio present
    const json1 = "{\"username\":\"alice\",\"bio\":\"A developer\"}";
    const value1 = try zjson.parse(json1, allocator, .{});
    defer zjson.freeValue(value1, allocator);

    const user1 = try zjson.unmarshal(User, value1, allocator);
    defer allocator.free(user1.username);
    defer if (user1.bio) |bio| allocator.free(bio);

    try std.testing.expect(std.mem.eql(u8, user1.username, "alice"));
    try std.testing.expect(user1.bio != null);

    // Test without bio
    const json2 = "{\"username\":\"bob\"}";
    const value2 = try zjson.parse(json2, allocator, .{});
    defer zjson.freeValue(value2, allocator);

    const user2 = try zjson.unmarshal(User, value2, allocator);
    defer allocator.free(user2.username);

    try std.testing.expect(std.mem.eql(u8, user2.username, "bob"));
    try std.testing.expect(user2.bio == null);
}

test "unmarshal nested structs" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const Address = struct {
        city: []const u8,
        zip: []const u8,
    };
    const Employee = struct {
        name: []const u8,
        address: Address,
    };

    const json = "{\"name\":\"Charlie\",\"address\":{\"city\":\"NYC\",\"zip\":\"10001\"}}";
    const value = try zjson.parse(json, allocator, .{});
    defer zjson.freeValue(value, allocator);

    const emp = try zjson.unmarshal(Employee, value, allocator);
    defer allocator.free(emp.name);
    defer allocator.free(emp.address.city);
    defer allocator.free(emp.address.zip);

    try std.testing.expect(std.mem.eql(u8, emp.name, "Charlie"));
    try std.testing.expect(std.mem.eql(u8, emp.address.city, "NYC"));
    try std.testing.expect(std.mem.eql(u8, emp.address.zip, "10001"));
}

test "unmarshal arrays of primitives" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const Config = struct {
        tags: [][]const u8,
    };

    const json = "{\"tags\":[\"rust\",\"zig\",\"golang\"]}";
    const value = try zjson.parse(json, allocator, .{});
    defer zjson.freeValue(value, allocator);

    const config = try zjson.unmarshal(Config, value, allocator);
    defer {
        for (config.tags) |tag| allocator.free(tag);
        allocator.free(config.tags);
    }

    try std.testing.expect(config.tags.len == 3);
    try std.testing.expect(std.mem.eql(u8, config.tags[0], "rust"));
    try std.testing.expect(std.mem.eql(u8, config.tags[1], "zig"));
    try std.testing.expect(std.mem.eql(u8, config.tags[2], "golang"));
}

test "unmarshal arrays of numbers" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const Stats = struct {
        scores: []i32,
    };

    const json = "{\"scores\":[95,87,92,88]}";
    const value = try zjson.parse(json, allocator, .{});
    defer zjson.freeValue(value, allocator);

    const stats = try zjson.unmarshal(Stats, value, allocator);
    defer allocator.free(stats.scores);

    try std.testing.expect(stats.scores.len == 4);
    try std.testing.expect(stats.scores[0] == 95);
    try std.testing.expect(stats.scores[1] == 87);
    try std.testing.expect(stats.scores[2] == 92);
    try std.testing.expect(stats.scores[3] == 88);
}

test "unmarshal floats" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const Measurement = struct {
        value: f64,
    };

    const json = "{\"value\":3.14159}";
    const value = try zjson.parse(json, allocator, .{});
    defer zjson.freeValue(value, allocator);

    const measurement = try zjson.unmarshal(Measurement, value, allocator);

    try std.testing.expect(measurement.value > 3.14 and measurement.value < 3.15);
}

test "unmarshal booleans" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const Feature = struct {
        enabled: bool,
        beta: bool,
    };

    const json = "{\"enabled\":true,\"beta\":false}";
    const value = try zjson.parse(json, allocator, .{});
    defer zjson.freeValue(value, allocator);

    const feature = try zjson.unmarshal(Feature, value, allocator);

    try std.testing.expect(feature.enabled == true);
    try std.testing.expect(feature.beta == false);
}

test "getFieldAs helper" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const json = "{\"name\":\"Dave\",\"count\":42}";
    const value = try zjson.parse(json, allocator, .{});
    defer zjson.freeValue(value, allocator);

    const name = try zjson.getFieldAs([]const u8, value, "name", allocator);
    defer if (name) |n| allocator.free(n);

    const count = try zjson.getFieldAs(i32, value, "count", allocator);

    try std.testing.expect(name != null);
    try std.testing.expect(count != null);
    try std.testing.expect(std.mem.eql(u8, name.?, "Dave"));
    try std.testing.expect(count.? == 42);
}

test "arrayAs helper" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const json = "[10,20,30,40,50]";
    const value = try zjson.parse(json, allocator, .{});
    defer zjson.freeValue(value, allocator);

    const numbers = try zjson.arrayAs(i32, value, allocator);
    defer allocator.free(numbers);

    try std.testing.expect(numbers.len == 5);
    try std.testing.expect(numbers[0] == 10);
    try std.testing.expect(numbers[2] == 30);
    try std.testing.expect(numbers[4] == 50);
}

test "unmarshal mixed complex structure" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const Article = struct {
        title: []const u8,
        views: u32,
        tags: [][]const u8,
        rating: f64,
    };

    const json =
        \\{
        \\  "title": "Zig Guide",
        \\  "views": 1500,
        \\  "tags": ["systems", "programming"],
        \\  "rating": 4.8
        \\}
    ;
    const value = try zjson.parse(json, allocator, .{});
    defer zjson.freeValue(value, allocator);

    const article = try zjson.unmarshal(Article, value, allocator);
    defer allocator.free(article.title);
    defer {
        for (article.tags) |tag| allocator.free(tag);
        allocator.free(article.tags);
    }

    try std.testing.expect(std.mem.eql(u8, article.title, "Zig Guide"));
    try std.testing.expect(article.views == 1500);
    try std.testing.expect(article.tags.len == 2);
    try std.testing.expect(article.rating > 4.7);
}

test "direct array unmarshal (slice)" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const json = "[10,20,30,40,50]";
    const value = try zjson.parse(json, allocator, .{});
    defer zjson.freeValue(value, allocator);

    const numbers = try zjson.unmarshal([]i32, value, allocator);
    defer allocator.free(numbers);

    try std.testing.expect(numbers.len == 5);
    try std.testing.expect(numbers[0] == 10);
    try std.testing.expect(numbers[4] == 50);
}

test "direct array unmarshal (fixed-size array)" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const json = "[1,2,3,4]";
    const value = try zjson.parse(json, allocator, .{});
    defer zjson.freeValue(value, allocator);

    const arr = try zjson.unmarshal([4]f64, value, allocator);

    try std.testing.expect(arr[0] == 1);
    try std.testing.expect(arr[1] == 2);
    try std.testing.expect(arr[2] == 3);
    try std.testing.expect(arr[3] == 4);
}

test "array of strings unmarshal" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const json = "[\"hello\",\"world\",\"zig\"]";
    const value = try zjson.parse(json, allocator, .{});
    defer zjson.freeValue(value, allocator);

    const words = try zjson.unmarshal([][]const u8, value, allocator);
    defer {
        for (words) |word| allocator.free(word);
        allocator.free(words);
    }

    try std.testing.expect(words.len == 3);
    try std.testing.expect(std.mem.eql(u8, words[0], "hello"));
    try std.testing.expect(std.mem.eql(u8, words[1], "world"));
    try std.testing.expect(std.mem.eql(u8, words[2], "zig"));
}
