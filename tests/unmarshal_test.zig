const std = @import("std");
const zjson = @import("zjson");
const test_utils = @import("test_utils.zig");

test "unmarshal structs and optionals" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            try test_utils.withParsed("{\"name\":\"Bob\",\"age\":25}", allocator, .{}, struct {
                fn check(value: zjson.Value, arena: std.mem.Allocator) !void {
                    const Person = struct {
                        name: []const u8,
                        age: u32,
                    };

                    const person = try zjson.unmarshal(Person, value, arena);
                    defer arena.free(person.name);
                    try std.testing.expect(std.mem.eql(u8, person.name, "Bob"));
                    try std.testing.expectEqual(@as(u32, 25), person.age);
                }
            }.check);

            try test_utils.withParsed("{\"username\":\"alice\",\"bio\":\"A developer\"}", allocator, .{}, struct {
                fn check(value: zjson.Value, arena: std.mem.Allocator) !void {
                    const User = struct {
                        username: []const u8,
                        bio: ?[]const u8,
                    };

                    const user = try zjson.unmarshal(User, value, arena);
                    defer arena.free(user.username);
                    defer if (user.bio) |bio| arena.free(bio);
                    try std.testing.expect(std.mem.eql(u8, user.username, "alice"));
                    try std.testing.expect(user.bio != null);
                }
            }.check);

            try test_utils.withParsed("{\"username\":\"bob\"}", allocator, .{}, struct {
                fn check(value: zjson.Value, arena: std.mem.Allocator) !void {
                    const User = struct {
                        username: []const u8,
                        bio: ?[]const u8,
                    };

                    const user = try zjson.unmarshal(User, value, arena);
                    defer arena.free(user.username);
                    try std.testing.expect(std.mem.eql(u8, user.username, "bob"));
                    try std.testing.expect(user.bio == null);
                }
            }.check);
        }
    }.run);
}

test "unmarshal nested data" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            try test_utils.withParsed("{\"name\":\"Charlie\",\"address\":{\"city\":\"NYC\",\"zip\":\"10001\"}}", allocator, .{}, struct {
                fn check(value: zjson.Value, arena: std.mem.Allocator) !void {
                    const Address = struct {
                        city: []const u8,
                        zip: []const u8,
                    };
                    const Employee = struct {
                        name: []const u8,
                        address: Address,
                    };

                    const emp = try zjson.unmarshal(Employee, value, arena);
                    defer arena.free(emp.name);
                    defer arena.free(emp.address.city);
                    defer arena.free(emp.address.zip);
                    try std.testing.expect(std.mem.eql(u8, emp.name, "Charlie"));
                    try std.testing.expect(std.mem.eql(u8, emp.address.city, "NYC"));
                    try std.testing.expect(std.mem.eql(u8, emp.address.zip, "10001"));
                }
            }.check);

            try test_utils.withParsed("{\"tags\":[\"rust\",\"zig\",\"golang\"]}", allocator, .{}, struct {
                fn check(value: zjson.Value, arena: std.mem.Allocator) !void {
                    const Config = struct {
                        tags: [][]const u8,
                    };

                    const config = try zjson.unmarshal(Config, value, arena);
                    defer {
                        for (config.tags) |tag| arena.free(tag);
                        arena.free(config.tags);
                    }
                    try std.testing.expectEqual(@as(usize, 3), config.tags.len);
                    try std.testing.expect(std.mem.eql(u8, config.tags[0], "rust"));
                    try std.testing.expect(std.mem.eql(u8, config.tags[1], "zig"));
                    try std.testing.expect(std.mem.eql(u8, config.tags[2], "golang"));
                }
            }.check);

            try test_utils.withParsed("{\"scores\":[95,87,92,88]}", allocator, .{}, struct {
                fn check(value: zjson.Value, arena: std.mem.Allocator) !void {
                    const Stats = struct {
                        scores: []i32,
                    };

                    const stats = try zjson.unmarshal(Stats, value, arena);
                    defer arena.free(stats.scores);
                    try std.testing.expectEqual(@as(usize, 4), stats.scores.len);
                    try std.testing.expectEqual(@as(i32, 95), stats.scores[0]);
                    try std.testing.expectEqual(@as(i32, 88), stats.scores[3]);
                }
            }.check);
        }
    }.run);
}

test "unmarshal numeric and boolean data" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            try test_utils.withParsed("{\"value\":3.14159}", allocator, .{}, struct {
                fn check(value: zjson.Value, arena: std.mem.Allocator) !void {
                    const Measurement = struct {
                        value: f64,
                    };
                    const measurement = try zjson.unmarshal(Measurement, value, arena);
                    try std.testing.expect(measurement.value > 3.14 and measurement.value < 3.15);
                }
            }.check);

            try test_utils.withParsed("{\"enabled\":true,\"beta\":false}", allocator, .{}, struct {
                fn check(value: zjson.Value, arena: std.mem.Allocator) !void {
                    const Feature = struct {
                        enabled: bool,
                        beta: bool,
                    };
                    const feature = try zjson.unmarshal(Feature, value, arena);
                    try std.testing.expect(feature.enabled);
                    try std.testing.expect(!feature.beta);
                }
            }.check);

            const article_json =
                \\{
                \\  "title": "Zig Guide",
                \\  "views": 1500,
                \\  "tags": ["systems", "programming"],
                \\  "rating": 4.8
                \\}
            ;
            try test_utils.withParsed(article_json, allocator, .{}, struct {
                fn check(value: zjson.Value, arena: std.mem.Allocator) !void {
                    const Article = struct {
                        title: []const u8,
                        views: u32,
                        tags: [][]const u8,
                        rating: f64,
                    };

                    const article = try zjson.unmarshal(Article, value, arena);
                    defer arena.free(article.title);
                    defer {
                        for (article.tags) |tag| arena.free(tag);
                        arena.free(article.tags);
                    }
                    try std.testing.expect(std.mem.eql(u8, article.title, "Zig Guide"));
                    try std.testing.expect(article.views == 1500);
                    try std.testing.expect(article.rating > 4.7);
                }
            }.check);
        }
    }.run);
}

test "unmarshal helpers" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            try test_utils.withParsed("{\"name\":\"Dave\",\"count\":42}", allocator, .{}, struct {
                fn check(value: zjson.Value, arena: std.mem.Allocator) !void {
                    const name = try zjson.getFieldAs([]const u8, value, "name", arena);
                    defer if (name) |n| arena.free(n);
                    const count = try zjson.getFieldAs(i32, value, "count", arena);
                    try std.testing.expect(name != null and count != null);
                    try std.testing.expect(std.mem.eql(u8, name.?, "Dave"));
                    try std.testing.expect(count.? == 42);
                }
            }.check);

            try test_utils.withParsed("[10,20,30,40,50]", allocator, .{}, struct {
                fn check(value: zjson.Value, arena: std.mem.Allocator) !void {
                    const numbers = try zjson.arrayAs(i32, value, arena);
                    defer arena.free(numbers);
                    try std.testing.expectEqual(@as(usize, 5), numbers.len);
                    try std.testing.expectEqual(@as(i32, 30), numbers[2]);
                }
            }.check);
        }
    }.run);
}

test "direct array and slice unmarshal" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            try test_utils.withParsed("[10,20,30,40,50]", allocator, .{}, struct {
                fn check(value: zjson.Value, arena: std.mem.Allocator) !void {
                    const numbers = try zjson.unmarshal([]i32, value, arena);
                    defer arena.free(numbers);
                    try std.testing.expectEqual(@as(usize, 5), numbers.len);
                    try std.testing.expectEqual(@as(i32, 50), numbers[4]);
                }
            }.check);

            try test_utils.withParsed("[1,2,3,4]", allocator, .{}, struct {
                fn check(value: zjson.Value, arena: std.mem.Allocator) !void {
                    const arr = try zjson.unmarshal([4]f64, value, arena);
                    try std.testing.expect(arr[0] == 1 and arr[3] == 4);
                }
            }.check);

            try test_utils.withParsed("[\"hello\",\"world\",\"zig\"]", allocator, .{}, struct {
                fn check(value: zjson.Value, arena: std.mem.Allocator) !void {
                    const words = try zjson.unmarshal([][]const u8, value, arena);
                    defer {
                        for (words) |word| arena.free(word);
                        arena.free(words);
                    }
                    try std.testing.expectEqual(@as(usize, 3), words.len);
                    try std.testing.expect(std.mem.eql(u8, words[1], "world"));
                }
            }.check);
        }
    }.run);
}
