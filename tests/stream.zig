const std = @import("std");
const zjson = @import("zjson");
const test_utils = @import("test_utils.zig");

test "stream parser - simple object" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            const json = "{\"name\":\"Alice\",\"age\":30}";
            var fbs = std.io.fixedBufferStream(json);
            var parser = zjson.stream.parser(fbs.reader(), allocator);
            defer parser.deinit();

            var token = (try parser.next()).?;
            try std.testing.expectEqual(zjson.stream.TokenType.object_begin, token.type);

            token = (try parser.next()).?;
            try std.testing.expectEqual(zjson.stream.TokenType.field_name, token.type);
            try std.testing.expectEqualStrings("name", token.data);
            if (token.allocated) allocator.free(token.data);

            token = (try parser.next()).?;
            try std.testing.expectEqual(zjson.stream.TokenType.string, token.type);
            try std.testing.expectEqualStrings("Alice", token.data);
            if (token.allocated) allocator.free(token.data);

            token = (try parser.next()).?;
            try std.testing.expectEqual(zjson.stream.TokenType.field_name, token.type);
            try std.testing.expectEqualStrings("age", token.data);
            if (token.allocated) allocator.free(token.data);

            token = (try parser.next()).?;
            try std.testing.expectEqual(zjson.stream.TokenType.number, token.type);
            try std.testing.expectEqualStrings("30", token.data);
            if (token.allocated) allocator.free(token.data);

            token = (try parser.next()).?;
            try std.testing.expectEqual(zjson.stream.TokenType.object_end, token.type);

            const next = try parser.next();
            try std.testing.expect(next == null);
        }
    }.run);
}

test "stream parser - array" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            const json = "[1,2,3]";
            var fbs = std.io.fixedBufferStream(json);
            var parser = zjson.stream.parser(fbs.reader(), allocator);
            defer parser.deinit();

            var token = (try parser.next()).?;
            try std.testing.expectEqual(zjson.stream.TokenType.array_begin, token.type);

            token = (try parser.next()).?;
            try std.testing.expectEqual(zjson.stream.TokenType.number, token.type);
            if (token.allocated) allocator.free(token.data);

            token = (try parser.next()).?;
            try std.testing.expectEqual(zjson.stream.TokenType.number, token.type);
            if (token.allocated) allocator.free(token.data);

            token = (try parser.next()).?;
            try std.testing.expectEqual(zjson.stream.TokenType.number, token.type);
            if (token.allocated) allocator.free(token.data);

            token = (try parser.next()).?;
            try std.testing.expectEqual(zjson.stream.TokenType.array_end, token.type);
        }
    }.run);
}

test "stream parser - nested structure" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            const json = "{\"users\":[{\"name\":\"Alice\"}]}";
            var fbs = std.io.fixedBufferStream(json);
            var parser = zjson.stream.parser(fbs.reader(), allocator);
            defer parser.deinit();

            var depth: usize = 0;
            while (try parser.next()) |token| {
                switch (token.type) {
                    .object_begin, .array_begin => depth += 1,
                    .object_end, .array_end => depth -= 1,
                    else => {},
                }
                if (token.allocated) allocator.free(token.data);
            }
            try std.testing.expectEqual(@as(usize, 0), depth);
        }
    }.run);
}

test "stream parser - boolean and null" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            const json = "[true,false,null]";
            var fbs = std.io.fixedBufferStream(json);
            var parser = zjson.stream.parser(fbs.reader(), allocator);
            defer parser.deinit();

            _ = try parser.next(); // array_begin

            var token = (try parser.next()).?;
            try std.testing.expectEqual(zjson.stream.TokenType.true_value, token.type);

            token = (try parser.next()).?;
            try std.testing.expectEqual(zjson.stream.TokenType.false_value, token.type);

            token = (try parser.next()).?;
            try std.testing.expectEqual(zjson.stream.TokenType.null_value, token.type);

            _ = try parser.next(); // array_end
        }
    }.run);
}

test "stream parser - escaped strings" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            const json = "[\"Hello\\nWorld\",\"\\\"quoted\\\"\"]";
            var fbs = std.io.fixedBufferStream(json);
            var parser = zjson.stream.parser(fbs.reader(), allocator);
            defer parser.deinit();

            _ = try parser.next(); // array_begin

            var token = (try parser.next()).?;
            try std.testing.expectEqual(zjson.stream.TokenType.string, token.type);
            try std.testing.expectEqualStrings("Hello\nWorld", token.data);
            if (token.allocated) allocator.free(token.data);

            token = (try parser.next()).?;
            try std.testing.expectEqual(zjson.stream.TokenType.string, token.type);
            try std.testing.expectEqualStrings("\"quoted\"", token.data);
            if (token.allocated) allocator.free(token.data);

            _ = try parser.next(); // array_end
        }
    }.run);
}

test "stream writer - simple object" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            var buffer = std.ArrayList(u8){};
            defer buffer.deinit(allocator);

            var writer = zjson.stream.writer(buffer.writer(allocator), allocator, .{ .pretty = false });
            defer writer.deinit();

            try writer.beginObject();
            try writer.writeField("name");
            try writer.writeString("Alice");
            try writer.writeField("age");
            try writer.writeInt(30);
            try writer.endObject();

            try std.testing.expectEqualStrings("{\"name\":\"Alice\",\"age\":30}", buffer.items);
        }
    }.run);
}

test "stream writer - array" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            var buffer = std.ArrayList(u8){};
            defer buffer.deinit(allocator);

            var writer = zjson.stream.writer(buffer.writer(allocator), allocator, .{ .pretty = false });
            defer writer.deinit();

            try writer.beginArray();
            try writer.writeInt(1);
            try writer.writeInt(2);
            try writer.writeInt(3);
            try writer.endArray();

            try std.testing.expectEqualStrings("[1,2,3]", buffer.items);
        }
    }.run);
}

test "stream writer - pretty print" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            var buffer = std.ArrayList(u8){};
            defer buffer.deinit(allocator);

            var writer = zjson.stream.writer(buffer.writer(allocator), allocator, .{ .pretty = true, .indent = 2 });
            defer writer.deinit();

            try writer.beginObject();
            try writer.writeField("name");
            try writer.writeString("Alice");
            try writer.endObject();

            const expected =
                \\{
                \\  "name": "Alice"
                \\}
            ;
            try std.testing.expectEqualStrings(expected, buffer.items);
        }
    }.run);
}

test "stream writer - nested structure" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            var buffer = std.ArrayList(u8){};
            defer buffer.deinit(allocator);

            var writer = zjson.stream.writer(buffer.writer(allocator), allocator, .{ .pretty = false });
            defer writer.deinit();

            try writer.beginObject();
            try writer.writeField("users");
            try writer.beginArray();
            try writer.beginObject();
            try writer.writeField("name");
            try writer.writeString("Alice");
            try writer.endObject();
            try writer.endArray();
            try writer.endObject();

            try std.testing.expectEqualStrings("{\"users\":[{\"name\":\"Alice\"}]}", buffer.items);
        }
    }.run);
}

test "stream writer - boolean and null" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            var buffer = std.ArrayList(u8){};
            defer buffer.deinit(allocator);

            var writer = zjson.stream.writer(buffer.writer(allocator), allocator, .{ .pretty = false });
            defer writer.deinit();

            try writer.beginArray();
            try writer.writeBool(true);
            try writer.writeBool(false);
            try writer.writeNull();
            try writer.endArray();

            try std.testing.expectEqualStrings("[true,false,null]", buffer.items);
        }
    }.run);
}

test "stream writer - string escaping" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            var buffer = std.ArrayList(u8){};
            defer buffer.deinit(allocator);

            var writer = zjson.stream.writer(buffer.writer(allocator), allocator, .{ .pretty = false });
            defer writer.deinit();

            try writer.beginArray();
            try writer.writeString("Hello\nWorld");
            try writer.writeString("\"quoted\"");
            try writer.endArray();

            try std.testing.expectEqualStrings("[\"Hello\\nWorld\",\"\\\"quoted\\\"\"]", buffer.items);
        }
    }.run);
}

test "stream writer - writeValue convenience" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            var buffer = std.ArrayList(u8){};
            defer buffer.deinit(allocator);

            var writer = zjson.stream.writer(buffer.writer(allocator), allocator, .{ .pretty = false });
            defer writer.deinit();

            const Person = struct {
                name: []const u8,
                age: u32,
            };

            try writer.writeValue(Person{ .name = "Alice", .age = 30 });

            try std.testing.expectEqualStrings("{\"name\":\"Alice\",\"age\":30}", buffer.items);
        }
    }.run);
}

test "stream roundtrip - parse and write" {
    try test_utils.usingAllocator(struct {
        fn run(allocator: std.mem.Allocator) !void {
            const original = "{\"name\":\"Alice\",\"numbers\":[1,2,3]}";

            // Parse
            var fbs = std.io.fixedBufferStream(original);
            var parser = zjson.stream.parser(fbs.reader(), allocator);
            defer parser.deinit();

            // Write
            var buffer = std.ArrayList(u8){};
            defer buffer.deinit(allocator);
            var writer = zjson.stream.writer(buffer.writer(allocator), allocator, .{ .pretty = false });
            defer writer.deinit();

            // Copy tokens from parser to writer
            while (try parser.next()) |token| {
                defer if (token.allocated) allocator.free(token.data);

                switch (token.type) {
                    .object_begin => try writer.beginObject(),
                    .object_end => try writer.endObject(),
                    .array_begin => try writer.beginArray(),
                    .array_end => try writer.endArray(),
                    .field_name => try writer.writeField(token.data),
                    .string => try writer.writeString(token.data),
                    .number => try writer.writeNumber(token.data),
                    .true_value => try writer.writeBool(true),
                    .false_value => try writer.writeBool(false),
                    .null_value => try writer.writeNull(),
                }
            }

            try std.testing.expectEqualStrings(original, buffer.items);
        }
    }.run);
}
