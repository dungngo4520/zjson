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

| Benchmark | Samples | zjson | std.json | Speedup |
|-----------|---------|-------|----------|---------|
| **Strings** | 100 | 172µs | 342µs | 1.99× |
| **Strings** | 10,000 | 11.59ms | 19.57ms | 1.69× |
| **Strings** | 1,000,000 | 1,168.7ms | 1,493.3ms | 1.28× |
| **Numbers** | 100 | 175µs | 326µs | 1.86× |
| **Numbers** | 10,000 | 15.87ms | 21.62ms | 1.36× |
| **Numbers** | 1,000,000 | 978.1ms | 1,884.7ms | 1.93× |
| **Objects** | 100 | 584µs | 909µs | 1.56× |
| **Objects** | 10,000 | 58.14ms | 116.63ms | 2.01× |
| **Objects** | 1,000,000 | 4.40s | 11.63s | 2.65× |
| **Objects** | 100 fields | 239µs | 509µs | 2.13× |
| **Objects** | 10,000 fields | 21.88ms | 42.20ms | 1.93× |
| **Objects** | 1,000,000 fields | 1.79s | 4.24s | 2.37× |
| **Nested arrays** | depth 100 | 302µs | 305µs | 1.01× |
| **Nested arrays** | depth 10,000 | 20.56ms | 12.85ms | 0.62× |
| **Nested arrays** | depth 1,000,000 | 1.28s | 2.11s | 1.65× |
| **Nested objects** | depth 100 | 318µs | 449µs | 1.41× |
| **Nested objects** | depth 10,000 | 26.97ms | 33.26ms | 1.23× |
| **Nested objects** | depth 1,000,000 | 1.90s | 4.42s | 2.33× |

Times in microseconds (µs), milliseconds (ms), or seconds (s). Hardware/Zig version variations expected.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
