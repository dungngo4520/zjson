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
    const json1 = zjson.stringify(.{ .hello = "world" });
    std.debug.print("{s}\n", .{json1});

    // Runtime stringify
    const person = Person{ .name = "Alice", .age = 30 };
    const json2 = try zjson.stringifyAlloc(person, allocator);
    defer allocator.free(json2);
    std.debug.print("{s}\n", .{json2});

    // Runtime parse
    const parsed = try zjson.parse("{\"name\":\"Bob\",\"age\":25}", allocator);
    defer zjson.freeValue(parsed, allocator);
}
```

## API Reference

### stringify(value)

Converts a Zig value to a JSON string at compile-time. The result is embedded in the binary as a constant.

```zig
pub fn stringify(comptime value: anytype) []const u8
```

### stringifyAlloc(value, allocator)

Converts a Zig value to a JSON string at runtime. Requires an allocator and returns an owned slice that must be freed.

```zig
pub fn stringifyAlloc(value: anytype, allocator: std.mem.Allocator) std.mem.Allocator.Error![]u8
```

### parse(input, allocator)

Parses a JSON string into a Value union type.

```zig
pub fn parse(input: []const u8, allocator: std.mem.Allocator) Error!Value
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
