# zjson

A lightweight, type-safe JSON library for Zig with compile-time serialization and runtime parsing.

## Requirements

Zig 0.15 or newer.

## Features

- Compile-time JSON serialization from Zig structs
- Runtime JSON parsing into a generic Value type
- Type-safe with full type information preserved
- Allocator-aware for flexible memory management
- Complete JSON escape sequence support
- Zero-copy parsing where possible

## Installation

Add to your build.zig.zon:

```zig
.{
    .name = "your-project",
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

### Compile-time Serialization

```zig
const std = @import("std");
const zjson = @import("zjson");

pub fn main() void {
    const Person = struct {
        name: []const u8,
        age: u8,
    };

    const person = Person{ .name = "Alice", .age = 30 };
    const json = zjson.stringify(person);
    std.debug.print("{s}\n", .{json});  // {"name":"Alice","age":30}
}
```

### Runtime Parsing

```zig
const std = @import("std");
const zjson = @import("zjson");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const json = "{\"name\":\"Bob\",\"age\":25}";
    const value = try zjson.parse(json, allocator);
    defer zjson.freeValue(value, allocator);

    if (value == .Object) {
        for (value.Object) |pair| {
            std.debug.print("{s}\n", .{pair.key});
        }
    }
}
```

## API Reference

### stringify(value)

```zig
pub fn stringify(comptime value: anytype) []const u8
```

Converts a Zig value to a JSON string at compile-time. Supported types:

- Primitives: bool, integers, floats, void (null)
- Strings with automatic escaping
- Enums (as tag name)
- Optional types
- Arrays and slices
- Structs
- Nested combinations

### parse(input, allocator)

```zig
pub fn parse(input: []const u8, allocator: std.mem.Allocator) Error!Value
```

Parses a JSON string into a Value union type. Returns an error if the JSON is invalid.

### freeValue(value, allocator)

```zig
pub fn freeValue(value: Value, allocator: std.mem.Allocator) void
```

Recursively frees all memory allocated by parse(). Must be called exactly once per parsed value.

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

pub const Pair = struct {
    key: []const u8,
    value: Value,
};
```

## Supported Types

### Stringify (Compile-time)

| Zig Type | Example | JSON Output |
|----------|---------|-------------|
| bool | true | true |
| u8..u64, i8..i64 | 42 | 42 |
| f16, f32, f64 | 3.14 | 3.14 |
| []const u8 | "hello" | "hello" |
| enum | Color.red | "red" |
| []T | &[_]i32{1,2,3} | [1,2,3] |
| struct | Person{...} | {...} |
| ?T | null / value | null / value |

### Parse (Runtime)

Returns a Value union with the following variants:

- Null - JSON null
- Bool: bool - JSON true / false
- Number: []const u8 - JSON number (as string)
- String: []const u8 - JSON string
- Array: []const Value - JSON array
- Object: []const Pair - JSON object

## Implementation Features

### String Escaping

All JSON escape sequences are properly handled:

```zig
// Stringify
zjson.stringify("hello\nworld");        // "hello\\nworld"
zjson.stringify("quote: \"test\"");     // "quote: \\\"test\\\""
zjson.stringify("path\\to\\file");      // "path\\\\to\\\\file"

// Parse
try zjson.parse("\"hello\\nworld\"", a);  // Result: "hello\nworld"
```

Supported escapes: \", \\, \/, \n, \r, \t, \b, \f, \uXXXX

### Optional Field Omission

Optional struct fields with null values are automatically omitted during serialization:

```zig
const User = struct {
    name: []const u8,
    email: ?[]const u8 = null,
};

const user = User{ .name = "Charlie", .email = null };
const json = zjson.stringify(user);
// Result: {"name":"Charlie"}
```

### Error Handling

```zig
pub const Error = error{
    UnexpectedEnd,
    InvalidSyntax,
    InvalidEscape,
    InvalidNumber,
    ExpectedColon,
    ExpectedCommaOrEnd,
    ExpectedValue,
    TrailingCharacters,
    OutOfMemory,
};
```

Example:

```zig
const value = zjson.parse(json, allocator) catch |err| {
    std.debug.print("Parse failed: {}\n", .{err});
    return;
};
```

## Testing

Run the test suite:

```bash
zig build test
```

Tests are organized by category:

- stringify_test.zig - Compile-time serialization tests
- parse_test.zig - Runtime parsing tests
- string_test.zig - String escaping tests

## Performance Characteristics

Stringify: Compile-time evaluation - zero runtime overhead
Parse: Single-pass parser with O(n) complexity
Numbers: Stored as strings to preserve arbitrary precision
Memory: Allocator-based, caller controls cleanup

## Building Examples

```bash
zig build examples
```

## Project Status

Early-stage: APIs are evolving. Contributions welcome.

## Contributing

Contributions are encouraged. Please:

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass: zig build test
5. Submit a Pull Request

Development guidelines:

- Follow existing code style
- Add tests for all new features
- Update README for API changes
- Test with zig build test before submitting

## Roadmap

- [x] Compile-time struct to JSON serialization
- [x] Runtime JSON to generic value parsing
- [x] Enum support
- [x] omitempty for optional fields
- [ ] Deserialize JSON to struct (typed deserialization)
- [ ] Custom field names / field renaming
- [ ] Better error messages with line/column info
- [ ] Streaming parser/encoder
- [ ] JSON schema validation

## License

This project is licensed under the MIT License - see the LICENSE file for details.
