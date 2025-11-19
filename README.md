# zjson

A lightweight, JSON library written in Zig.

## Requirements

Zig 0.15 or newer.

## Features

- Compile-time JSON serialization
- Runtime JSON serialization and parsing

## Installation

Add to your build.zig.zon:

```zig
.{
    .name = .your-project,
    .version = "0.0.1",
    .dependencies = .{
        .zjson = .{
            .url = "https://github.com/dungngo4520/zjson/archive/refs/tags/v0.1.0.tar.gz",
        },
    },
}
```

Then in your build.zig:

```zig
exe.root_module.addImport("zjson", b.dependency("zjson").module("zjson"));
```

## Quick Start

```zig
const std = @import("std");
const zjson = @import("zjson");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const Person = struct {
        name: []const u8,
        age: u32,
    };

    // Compile-time stringify
    const json1 = zjson.stringify(.{ .hello = "world" }, .{});
    std.debug.print("{s}\n", .{json1});

    // Runtime stringify with options
    const person = Person{ .name = "Alice", .age = 30 };
    const json2 = try zjson.stringifyAlloc(person, allocator, .{
        .pretty = true,
        .indent = 2,
    });
    defer allocator.free(json2);
    std.debug.print("{s}\n", .{json2});
    // Runtime parse with default options
    const parsed = try zjson.parse("{\"name\":\"Bob\",\"age\":25}", allocator, .{});
    defer zjson.freeValue(parsed, allocator);

    // Parse with trailing commas allowed
    const with_trailing = try zjson.parse("[1,2,3,]", allocator, .{ .allow_trailing_commas = true });
    defer zjson.freeValue(with_trailing, allocator);

    // Parse with comments allowed
    const with_comments = try zjson.parse("/* comment */ {\"x\": 1}", allocator, .{ .allow_comments = true });
    defer zjson.freeValue(with_comments, allocator);
}
```

## API Reference

### stringify(value, options)

Converts a Zig value to a JSON string at compile-time. The result is embedded in the binary as a constant.

```zig
pub fn stringify(comptime value: anytype, comptime options: StringifyOptions) []const u8
```

### stringifyAlloc(value, allocator, options)

Converts a Zig value to a JSON string at runtime. Requires an allocator and returns an owned slice that must be freed.

```zig
pub fn stringifyAlloc(value: anytype, allocator: std.mem.Allocator, options: StringifyOptions) std.mem.Allocator.Error![]u8
```

### StringifyOptions

Control JSON output formatting:

```zig
pub const StringifyOptions = struct {
    pretty: bool = false,           // Enable pretty-printing with newlines
    indent: u32 = 2,                // Indentation level (spaces)
    omit_null: bool = true,         // Skip null-valued fields
    sort_keys: bool = false,        // Sort object keys (not yet implemented)
};
```

### parse(input, allocator, options)

Parses a JSON string into a Value union type. Requires an allocator and parse options.

```zig
pub fn parse(input: []const u8, allocator: std.mem.Allocator, options: ParseOptions) Error!Value
```

### ParseOptions

Control JSON parsing behavior:

```zig
pub const ParseOptions = struct {
    allow_comments: bool = false,         // Allow // and /* */ comments
    allow_trailing_commas: bool = false,  // Allow trailing commas in arrays and objects
    allow_control_chars: bool = false,    // Allow control characters in whitespace
};
```

### freeValue(value, allocator)

Recursively frees all memory allocated by parse().

```zig
pub fn freeValue(value: Value, allocator: std.mem.Allocator) void
```

### Value Type

```zig
pub const Value = union(enum) {
    Null,
    Bool: bool,
    Number: []const u8,
    String: []const u8,
    Array: []const Value,
    Object: []const Pair,
};
```

## Implementation Features

### Supported Types

Both stringify() and stringifyAlloc() support:

- Primitives: bool, integers, floats, void (null)
- Strings with automatic escaping
- Enums (as tag name)
- Optional types
- Arrays and slices
- Structs
- Nested combinations

## License

This project is licensed under the MIT License - see the LICENSE file for details.
