# zjson

High-performance JSON library for Zig.

**Requires:** Zig 0.15+

## Features

- Fast arena-based parsing
- Compile-time & runtime marshaling
- Streaming parse/write for large files
- Custom marshal/unmarshal hooks
- Error reporting with line/column info
- Supports comments & trailing commas (via options)

## Installation

Add to `build.zig.zon`:

```zig
.zjson = .{
    .url = "https://github.com/dungngo4520/zjson/archive/refs/tags/v0.1.0.tar.gz",
},
```

In `build.zig`:

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

    // Parse JSON
    var result = try zjson.parse("{\"name\":\"Alice\",\"age\":30}", allocator, .{});
    defer result.deinit();

    // Get values
    if (try zjson.getObjectField(result.value, "name")) |name| {
        std.debug.print("Name: {s}\n", .{try zjson.toString(name)});
    }

    // Marshal struct to JSON
    const Data = struct { name: []const u8, age: u32 };
    const data = Data{ .name = "Bob", .age = 25 };
    const json = try zjson.marshalAlloc(data, allocator, .{});
    defer allocator.free(json);
}
```

## Examples

See `examples/` directory. Run with `zig build examples`.

## Performance

Benchmarks vs `std.json.parseFromSlice` (Zig 0.15.0, ReleaseFast):

| Benchmark | Input | zjson | std.json | Speedup |
|-----------|-------|-------|----------|---------|
| **Strings** | 100 strings | 208µs | 334µs | 1.61× |
| **Strings** | 1,000 strings | 1,243µs | 1,977µs | 1.59× |
| **Strings** | 5,000 strings | 5,499µs | 10,005µs | 1.82× |
| **Objects** | 10 objects | 115µs | 220µs | 1.91× |
| **Objects** | 100 objects | 577µs | 932µs | 1.62× |
| **Objects** | 100-field object | 253µs | 499µs | 1.97× |
| **Objects** | 50-field object | 151µs | 340µs | 2.25× |
| **Multi-field object** | 10 fields | 66µs | 158µs | 2.39× |

Times are microseconds per parse. Optimization phases completed: Phase 1 (generic lexer architecture). Hardware/Zig version variations expected. Stack-based parsing provides excellent performance on typical JSON structures.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
