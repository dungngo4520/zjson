# zjson

A lightweight, JSON library written in Zig.

## Requirements

Zig 0.15 or newer.

## Features

- Compile-time JSON serialization
- Runtime JSON serialization and parsing
- Generic struct unmarshaling

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

    // Marshal
    const person = Person{ .name = "Alice", .age = 30 };
    const json = try zjson.marshalAlloc(person, allocator, .{});
    defer allocator.free(json);
    std.debug.print("JSON: {s}\n", .{json});

    // Parse directly into an arena-backed tree
    var parsed = try zjson.parseToArena("{\"name\":\"Bob\",\"age\":25}", allocator, .{});
    defer parsed.deinit();

    // Unmarshal into struct
    const person2 = try zjson.unmarshal(Person, parsed.value, allocator);
    defer allocator.free(person2.name);
    std.debug.print("Name: {s}, Age: {d}\n", .{ person2.name, person2.age });
}
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.
