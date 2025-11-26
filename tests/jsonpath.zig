const std = @import("std");
const zjson = @import("zjson");

test "jsonpath basic child access" {
    const allocator = std.testing.allocator;

    const json =
        \\{"store": {"book": "test", "price": 10}}
    ;

    var result = try zjson.parse(json, allocator, .{});
    defer result.deinit();

    const matches = try zjson.jsonpath(allocator, result.value, "$.store.book");
    defer allocator.free(matches);

    try std.testing.expectEqual(@as(usize, 1), matches.len);
    try std.testing.expectEqualStrings("test", matches[0].String);
}

test "jsonpath wildcard" {
    const allocator = std.testing.allocator;

    const json =
        \\{"a": 1, "b": 2, "c": 3}
    ;

    var result = try zjson.parse(json, allocator, .{});
    defer result.deinit();

    const matches = try zjson.jsonpath(allocator, result.value, "$.*");
    defer allocator.free(matches);

    try std.testing.expectEqual(@as(usize, 3), matches.len);
}

test "jsonpath array index" {
    const allocator = std.testing.allocator;

    const json =
        \\{"items": ["a", "b", "c"]}
    ;

    var result = try zjson.parse(json, allocator, .{});
    defer result.deinit();

    // First element
    const first = try zjson.jsonpath(allocator, result.value, "$.items[0]");
    defer allocator.free(first);
    try std.testing.expectEqual(@as(usize, 1), first.len);
    try std.testing.expectEqualStrings("a", first[0].String);

    // Last element (negative index)
    const last = try zjson.jsonpath(allocator, result.value, "$.items[-1]");
    defer allocator.free(last);
    try std.testing.expectEqual(@as(usize, 1), last.len);
    try std.testing.expectEqualStrings("c", last[0].String);
}

test "jsonpath array slice" {
    const allocator = std.testing.allocator;

    const json =
        \\[0, 1, 2, 3, 4, 5]
    ;

    var result = try zjson.parse(json, allocator, .{});
    defer result.deinit();

    // First 3 elements [0:3]
    const slice1 = try zjson.jsonpath(allocator, result.value, "$[0:3]");
    defer allocator.free(slice1);
    try std.testing.expectEqual(@as(usize, 3), slice1.len);

    // Last 2 elements [-2:]
    const slice2 = try zjson.jsonpath(allocator, result.value, "$[-2:]");
    defer allocator.free(slice2);
    try std.testing.expectEqual(@as(usize, 2), slice2.len);

    // Every other element [::2]
    const slice3 = try zjson.jsonpath(allocator, result.value, "$[::2]");
    defer allocator.free(slice3);
    try std.testing.expectEqual(@as(usize, 3), slice3.len);
}

test "jsonpath recursive descent" {
    const allocator = std.testing.allocator;

    const json =
        \\{
        \\  "store": {
        \\    "book": [
        \\      {"author": "Alice", "price": 10},
        \\      {"author": "Bob", "price": 20}
        \\    ],
        \\    "owner": {"name": "Charlie"}
        \\  }
        \\}
    ;

    var result = try zjson.parse(json, allocator, .{});
    defer result.deinit();

    // Find all authors
    const authors = try zjson.jsonpath(allocator, result.value, "$..author");
    defer allocator.free(authors);
    try std.testing.expectEqual(@as(usize, 2), authors.len);

    // Find all prices
    const prices = try zjson.jsonpath(allocator, result.value, "$..price");
    defer allocator.free(prices);
    try std.testing.expectEqual(@as(usize, 2), prices.len);
}

test "jsonpath filter expression" {
    const allocator = std.testing.allocator;

    const json =
        \\{
        \\  "books": [
        \\    {"title": "A", "price": 5},
        \\    {"title": "B", "price": 15},
        \\    {"title": "C", "price": 8}
        \\  ]
        \\}
    ;

    var result = try zjson.parse(json, allocator, .{});
    defer result.deinit();

    // Books under $10
    const cheap = try zjson.jsonpath(allocator, result.value, "$.books[?(@.price < 10)]");
    defer allocator.free(cheap);
    try std.testing.expectEqual(@as(usize, 2), cheap.len);

    // Books over $10
    const expensive = try zjson.jsonpath(allocator, result.value, "$.books[?(@.price > 10)]");
    defer allocator.free(expensive);
    try std.testing.expectEqual(@as(usize, 1), expensive.len);
}

test "jsonpath union" {
    const allocator = std.testing.allocator;

    const json =
        \\{"a": 1, "b": 2, "c": 3}
    ;

    var result = try zjson.parse(json, allocator, .{});
    defer result.deinit();

    // Multiple keys
    const matches = try zjson.jsonpath(allocator, result.value, "$['a','c']");
    defer allocator.free(matches);
    try std.testing.expectEqual(@as(usize, 2), matches.len);
}

test "jsonpath index union" {
    const allocator = std.testing.allocator;

    const json =
        \\["a", "b", "c", "d"]
    ;

    var result = try zjson.parse(json, allocator, .{});
    defer result.deinit();

    const matches = try zjson.jsonpath(allocator, result.value, "$[0,2]");
    defer allocator.free(matches);
    try std.testing.expectEqual(@as(usize, 2), matches.len);
    try std.testing.expectEqualStrings("a", matches[0].String);
    try std.testing.expectEqualStrings("c", matches[1].String);
}

test "jsonpath bracket notation" {
    const allocator = std.testing.allocator;

    const json =
        \\{"user": {"name": "test"}}
    ;

    var result = try zjson.parse(json, allocator, .{});
    defer result.deinit();

    const matches = try zjson.jsonpath(allocator, result.value, "$['user']['name']");
    defer allocator.free(matches);
    try std.testing.expectEqual(@as(usize, 1), matches.len);
    try std.testing.expectEqualStrings("test", matches[0].String);
}

test "jsonpath queryOne" {
    const allocator = std.testing.allocator;

    const json =
        \\{"name": "Alice"}
    ;

    var result = try zjson.parse(json, allocator, .{});
    defer result.deinit();

    const match = try zjson.jsonpathOne(allocator, result.value, "$.name");
    try std.testing.expect(match != null);
    try std.testing.expectEqualStrings("Alice", match.?.String);

    const no_match = try zjson.jsonpathOne(allocator, result.value, "$.missing");
    try std.testing.expect(no_match == null);
}

test "jsonpath filter existence check" {
    const allocator = std.testing.allocator;

    const json =
        \\{
        \\  "books": [
        \\    {"title": "A"},
        \\    {"title": "B", "isbn": "123"},
        \\    {"title": "C", "isbn": "456"}
        \\  ]
        \\}
    ;

    var result = try zjson.parse(json, allocator, .{});
    defer result.deinit();

    // Books with isbn field
    const with_isbn = try zjson.jsonpath(allocator, result.value, "$.books[?(@.isbn)]");
    defer allocator.free(with_isbn);
    try std.testing.expectEqual(@as(usize, 2), with_isbn.len);
}
