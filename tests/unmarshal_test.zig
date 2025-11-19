const std = @import("std");
const zjson = @import("zjson");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("Testing unmarshal functionality...\n\n", .{});

    // Test 1: Simple struct with primitives
    {
        std.debug.print("Test 1: Simple struct with primitives\n", .{});
        const Person = struct {
            name: []const u8,
            age: u32,
        };

        const json = "{\"name\":\"Bob\",\"age\":25}";
        const value = try zjson.parse(json, allocator, .{});
        defer zjson.freeValue(value, allocator);

        const person = try zjson.unmarshal(Person, value, allocator);
        defer allocator.free(person.name);

        std.debug.print("  name={s}, age={d}\n", .{ person.name, person.age });
        if (std.mem.eql(u8, person.name, "Bob") and person.age == 25) {
            std.debug.print("  ✓ PASS\n\n", .{});
        } else {
            std.debug.print("  ✗ FAIL\n\n", .{});
            return error.TestFailed;
        }
    }

    // Test 2: Struct with optional fields
    {
        std.debug.print("Test 2: Struct with optional fields\n", .{});
        const User = struct {
            username: []const u8,
            bio: ?[]const u8,
        };

        const json1 = "{\"username\":\"alice\",\"bio\":\"A developer\"}";
        const value1 = try zjson.parse(json1, allocator, .{});
        defer zjson.freeValue(value1, allocator);

        const user1 = try zjson.unmarshal(User, value1, allocator);
        defer allocator.free(user1.username);
        defer if (user1.bio) |bio| allocator.free(bio);

        std.debug.print("  user1: username={s}, bio={s}\n", .{ user1.username, user1.bio.? });
        if (std.mem.eql(u8, user1.username, "alice") and user1.bio != null) {
            std.debug.print("  ✓ PASS (with bio)\n", .{});
        } else {
            std.debug.print("  ✗ FAIL\n", .{});
            return error.TestFailed;
        }

        const json2 = "{\"username\":\"bob\"}";
        const value2 = try zjson.parse(json2, allocator, .{});
        defer zjson.freeValue(value2, allocator);

        const user2 = try zjson.unmarshal(User, value2, allocator);
        defer allocator.free(user2.username);

        std.debug.print("  user2: username={s}, bio={}\n", .{ user2.username, user2.bio });
        if (std.mem.eql(u8, user2.username, "bob") and user2.bio == null) {
            std.debug.print("  ✓ PASS (without bio)\n\n", .{});
        } else {
            std.debug.print("  ✗ FAIL\n\n", .{});
            return error.TestFailed;
        }
    }

    // Test 3: Nested structs
    {
        std.debug.print("Test 3: Nested structs\n", .{});
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

        std.debug.print("  name={s}, city={s}, zip={s}\n", .{ emp.name, emp.address.city, emp.address.zip });
        if (std.mem.eql(u8, emp.name, "Charlie") and std.mem.eql(u8, emp.address.city, "NYC")) {
            std.debug.print("  ✓ PASS\n\n", .{});
        } else {
            std.debug.print("  ✗ FAIL\n\n", .{});
            return error.TestFailed;
        }
    }

    // Test 4: Arrays of primitives
    {
        std.debug.print("Test 4: Arrays of primitives\n", .{});
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

        std.debug.print("  tags count={d}: ", .{config.tags.len});
        for (config.tags) |tag| {
            std.debug.print("[{s}] ", .{tag});
        }
        std.debug.print("\n", .{});

        if (config.tags.len == 3 and std.mem.eql(u8, config.tags[0], "rust")) {
            std.debug.print("  ✓ PASS\n\n", .{});
        } else {
            std.debug.print("  ✗ FAIL\n\n", .{});
            return error.TestFailed;
        }
    }

    // Test 5: Arrays of numbers
    {
        std.debug.print("Test 5: Arrays of numbers\n", .{});
        const Stats = struct {
            scores: []i32,
        };

        const json = "{\"scores\":[95,87,92,88]}";
        const value = try zjson.parse(json, allocator, .{});
        defer zjson.freeValue(value, allocator);

        const stats = try zjson.unmarshal(Stats, value, allocator);
        defer allocator.free(stats.scores);

        std.debug.print("  scores: ", .{});
        for (stats.scores) |score| {
            std.debug.print("{d} ", .{score});
        }
        std.debug.print("\n", .{});

        if (stats.scores.len == 4 and stats.scores[0] == 95) {
            std.debug.print("  ✓ PASS\n\n", .{});
        } else {
            std.debug.print("  ✗ FAIL\n\n", .{});
            return error.TestFailed;
        }
    }

    // Test 6: Floats
    {
        std.debug.print("Test 6: Floats\n", .{});
        const Measurement = struct {
            value: f64,
        };

        const json = "{\"value\":3.14159}";
        const value = try zjson.parse(json, allocator, .{});
        defer zjson.freeValue(value, allocator);

        const measurement = try zjson.unmarshal(Measurement, value, allocator);
        std.debug.print("  value={d:.5}\n", .{measurement.value});

        if (measurement.value > 3.14 and measurement.value < 3.15) {
            std.debug.print("  ✓ PASS\n\n", .{});
        } else {
            std.debug.print("  ✗ FAIL\n\n", .{});
            return error.TestFailed;
        }
    }

    // Test 7: Booleans
    {
        std.debug.print("Test 7: Booleans\n", .{});
        const Feature = struct {
            enabled: bool,
            beta: bool,
        };

        const json = "{\"enabled\":true,\"beta\":false}";
        const value = try zjson.parse(json, allocator, .{});
        defer zjson.freeValue(value, allocator);

        const feature = try zjson.unmarshal(Feature, value, allocator);
        std.debug.print("  enabled={}, beta={}\n", .{ feature.enabled, feature.beta });

        if (feature.enabled == true and feature.beta == false) {
            std.debug.print("  ✓ PASS\n\n", .{});
        } else {
            std.debug.print("  ✗ FAIL\n\n", .{});
            return error.TestFailed;
        }
    }

    // Test 8: getFieldAs helper
    {
        std.debug.print("Test 8: getFieldAs helper\n", .{});
        const json = "{\"name\":\"Dave\",\"count\":42}";
        const value = try zjson.parse(json, allocator, .{});
        defer zjson.freeValue(value, allocator);

        const name = try zjson.getFieldAs([]const u8, value, "name", allocator);
        defer if (name) |n| allocator.free(n);

        const count = try zjson.getFieldAs(i32, value, "count", allocator);

        std.debug.print("  name={s}, count={d}\n", .{ name.?, count.? });

        if (name != null and count != null and count.? == 42) {
            std.debug.print("  ✓ PASS\n\n", .{});
        } else {
            std.debug.print("  ✗ FAIL\n\n", .{});
            return error.TestFailed;
        }
    }

    // Test 9: arrayAs helper
    {
        std.debug.print("Test 9: arrayAs helper\n", .{});
        const json = "[10,20,30,40,50]";
        const value = try zjson.parse(json, allocator, .{});
        defer zjson.freeValue(value, allocator);

        const numbers = try zjson.arrayAs(i32, value, allocator);
        defer allocator.free(numbers);

        std.debug.print("  array: ", .{});
        for (numbers) |num| {
            std.debug.print("{d} ", .{num});
        }
        std.debug.print("\n", .{});

        if (numbers.len == 5 and numbers[2] == 30) {
            std.debug.print("  ✓ PASS\n\n", .{});
        } else {
            std.debug.print("  ✗ FAIL\n\n", .{});
            return error.TestFailed;
        }
    }

    // Test 10: Mixed complex structure
    {
        std.debug.print("Test 10: Mixed complex structure\n", .{});
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

        std.debug.print("  title={s}, views={d}, tags={d}, rating={d:.1}\n", .{
            article.title,
            article.views,
            article.tags.len,
            article.rating,
        });

        if (article.views == 1500 and article.tags.len == 2 and article.rating > 4.7) {
            std.debug.print("  ✓ PASS\n\n", .{});
        } else {
            std.debug.print("  ✗ FAIL\n\n", .{});
            return error.TestFailed;
        }
    }

    // Test 11: Direct array unmarshal (slice)
    {
        std.debug.print("Test 11: Direct array unmarshal (slice)\n", .{});
        const json = "[10,20,30,40,50]";
        const value = try zjson.parse(json, allocator, .{});
        defer zjson.freeValue(value, allocator);

        const numbers = try zjson.unmarshal([]i32, value, allocator);
        defer allocator.free(numbers);

        std.debug.print("  slice: ", .{});
        for (numbers) |num| {
            std.debug.print("{d} ", .{num});
        }
        std.debug.print("\n", .{});

        if (numbers.len == 5 and numbers[0] == 10 and numbers[4] == 50) {
            std.debug.print("  ✓ PASS\n\n", .{});
        } else {
            std.debug.print("  ✗ FAIL\n\n", .{});
            return error.TestFailed;
        }
    }

    // Test 12: Direct array unmarshal (fixed-size array)
    {
        std.debug.print("Test 12: Direct array unmarshal (fixed-size array)\n", .{});
        const json = "[1,2,3,4]";
        const value = try zjson.parse(json, allocator, .{});
        defer zjson.freeValue(value, allocator);

        const arr = try zjson.unmarshal([4]f64, value, allocator);

        std.debug.print("  array: ", .{});
        for (arr) |num| {
            std.debug.print("{d:.1} ", .{num});
        }
        std.debug.print("\n", .{});

        if (arr[0] == 1 and arr[3] == 4) {
            std.debug.print("  ✓ PASS\n\n", .{});
        } else {
            std.debug.print("  ✗ FAIL\n\n", .{});
            return error.TestFailed;
        }
    }

    // Test 13: Array of strings unmarshal
    {
        std.debug.print("Test 13: Array of strings unmarshal\n", .{});
        const json = "[\"hello\",\"world\",\"zig\"]";
        const value = try zjson.parse(json, allocator, .{});
        defer zjson.freeValue(value, allocator);

        const words = try zjson.unmarshal([][]const u8, value, allocator);
        defer {
            for (words) |word| allocator.free(word);
            allocator.free(words);
        }

        std.debug.print("  words: ", .{});
        for (words) |word| {
            std.debug.print("[{s}] ", .{word});
        }
        std.debug.print("\n", .{});

        if (words.len == 3 and std.mem.eql(u8, words[0], "hello")) {
            std.debug.print("  ✓ PASS\n\n", .{});
        } else {
            std.debug.print("  ✗ FAIL\n\n", .{});
            return error.TestFailed;
        }
    }

    std.debug.print("All tests passed! ✓\n", .{});
}
