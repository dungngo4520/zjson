# zjson

A lightweight, JSON library written in Zig.

## Requirements

Zig 0.15 or newer.

## Features

- Turn Zig structs into JSON at compile time and runtime.
- Parse JSON text into an arena-backed tree.
- Unmarshal JSON into typed structs with one call.

## API basics

- Import everything with `const zjson = @import("zjson");`.
- Parsing: `parseToArena(text, allocator, options)` returns a `ParseResult` (call `deinit` when done).
- Parse errors: after `parseToArena` fails, call `lastParseErrorInfo()` for byte/line/column info and pass it to `writeParseErrorIndicator()` to show a caret on the offending line.
- Marshaling: `marshal` and `marshalAlloc` turn Zig data into JSON.
- Unmarshaling: `unmarshal(Type, value, allocator)` plus helpers like `getFieldAs` and `arrayAs`.
- Quick value helpers: `toI64`, `toF64`, `toBool`, `toString`, `getObjectField`, `getArrayElement`, `arrayLen`, `objectLen`, `isNull`.
- Custom hooks: `marshalWithCustom` / `unmarshalWithCustom` let you override defaults for special types.

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

## Examples

- `examples/parse.zig` parses a few basic values.
- `examples/error_info.zig` shows how to call `lastParseErrorInfo()` and `writeParseErrorIndicator()` when parsing fails.

Run any example with:

```sh
zig build examples && zig-out/examples/<example-name>
```

## Benchmarks

Benchmarks compare `zjson.parseToArena` against `std.json.parseFromSlice` (Zig 0.15.0, `ReleaseFast`). Times are microseconds per parse.

### Numbers (array of integers)

| Count | zjson (µs) | std.json (µs) | Speedup |
| --- | --- | --- | --- |
| 100 | 98 | 318 | 3.24× |
| 1,000 | 391 | 1,680 | 4.30× |
| 10,000 | 3,112 | 22,141 | 7.11× |
| 50,000 | 14,861 | 103,760 | 6.98× |

### Strings (array of short strings)

| Count | zjson (µs) | std.json (µs) | Speedup |
| --- | --- | --- | --- |
| 100 | 161 | 312 | 1.94× |
| 1,000 | 604 | 2,083 | 3.45× |
| 5,000 | 2,599 | 9,793 | 3.77× |

### Objects (flat objects & varying field counts)

| Case | zjson (µs) | std.json (µs) | Speedup |
| --- | --- | --- | --- |
| 10 objects | 69 | 243 | 3.52× |
| 50 objects | 200 | 601 | 3.01× |
| 100 objects | 333 | 947 | 2.84× |
| object, 10 fields | 34 | 166 | 4.88× |
| object, 50 fields | 85 | 349 | 4.11× |
| object, 100 fields | 135 | 508 | 3.76× |

### Deeply nested structures

| Case | zjson (µs) | std.json (µs) | Speedup |
| --- | --- | --- | --- |
| arrays depth 50 | 177 | 210 | 1.19× |
| arrays depth 1,000 | 1,141 | 1,540 | 1.35× |
| objects depth 50 | 188 | 320 | 1.70× |
| objects depth 1,000 | 1,428 | 3,159 | 2.21× |

Benchmark numbers will vary across hardware and Zig releases, but they illustrate the typical speedup range you can expect when switching from `std.json` to zjson.

### Scope & limitations

- These benchmarks measure parsing throughput only
- Input data may not reflect real-world JSON documents
- Results compare against `std.json.parseFromSlice` only

## License

This project is licensed under the MIT License - see the LICENSE file for details.
