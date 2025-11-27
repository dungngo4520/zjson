# zjson

Fast JSON library for Zig 0.15+

## Install

```zig
// build.zig.zon
.zjson = .{
    .url = "https://github.com/dungngo4520/zjson/archive/refs/tags/v1.0.0.tar.gz",
},

// build.zig
exe.root_module.addImport("zjson", b.dependency("zjson", .{}).module("zjson"));
```

## API

### Parse

```zig
var result = try zjson.parse(json_string, allocator, .{});
defer result.deinit();

const name = try zjson.value.as([]const u8, (try zjson.value.getField(result.value, "name")).?);
const age = try zjson.value.as(i64, (try zjson.value.getField(result.value, "age")).?);
```

### Unmarshal

```zig
const Person = struct { name: []const u8, age: i32 };
const person = try zjson.unmarshal(Person, result.value, allocator);
```

### JSON Pointer (RFC 6901)

```zig
const name = try zjson.pointer.get(result.value, "/users/0/name");
const age = try zjson.pointer.getAs(i64, result.value, "/users/0/age");
if (zjson.pointer.has(result.value, "/users/1")) { ... }
```

### JSONPath Query

```zig
// Query returns all matches
const authors = try zjson.path.query(allocator, result.value, "$..author");
defer allocator.free(authors);

// Query with filter
const cheap = try zjson.path.query(allocator, result.value, "$.books[?(@.price < 10)]");

// Get first match or null
const first = try zjson.path.queryOne(allocator, result.value, "$.store.name");
```

Supported: `$` root, `.key` child, `[0]` index, `[-1]` negative, `[0:3]` slice, `[*]` wildcard, `..` recursive, `['a','b']` union, `[?(@.x < 5)]` filter.

### Marshal

```zig
const json = try zjson.marshalAlloc(person, allocator, .{ .pretty = true });
defer allocator.free(json);
```

### Stream

```zig
// Parse
var parser = zjson.stream.parser(reader, allocator);
while (try parser.next()) |token| { ... }

// Write
var writer = zjson.stream.writer(file.writer(), allocator, .{});
try writer.beginObject();
try writer.objectField("key");
try writer.write("value");
try writer.endObject();
```

## Options

```zig
// ParseOptions
.max_depth = 128
.max_document_size = 10_000_000
.duplicate_key_policy = .keep_last  // .keep_first, .reject

// MarshalOptions
.pretty = false
.indent = 2
.omit_null = true
.sort_keys = false
.use_tabs = false
.compact_arrays = false
.line_ending = .lf  // .crlf
```

## Custom Serialization

```zig
const MyType = struct {
    data: i32,

    pub fn marshal(self: MyType) zjson.Value {
        return .{ .String = "custom" };
    }

    pub fn unmarshal(val: zjson.Value, allocator: Allocator) !MyType {
        return .{ .data = try zjson.value.as(i32, val) };
    }
};
```

## Performance

1.28-2.65x faster than std.json across all workloads.

## License

MIT
