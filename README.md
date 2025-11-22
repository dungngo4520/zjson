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

| Benchmark | Count | zjson | std.json | Speedup |
|-----------|-------|-------|----------|---------|
| **Numbers** | 1,000 | 391µs | 1,680µs | 4.3× |
| **Numbers** | 10,000 | 3.1ms | 22.1ms | 7.1× |
| **Strings** | 1,000 | 604µs | 2,083µs | 3.5× |
| **Objects** | 100 | 333µs | 947µs | 2.8× |
| **Nested (depth 1000)** | — | 1.4ms | 3.2ms | 2.2× |

Times are microseconds per parse. Hardware/Zig version variations expected.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
