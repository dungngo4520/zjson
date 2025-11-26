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

const name = try zjson.toString((try zjson.getObjectField(result.value, "name")).?);
const age = try zjson.toI64((try zjson.getObjectField(result.value, "age")).?);
```

### Unmarshal

```zig
const Person = struct { name: []const u8, age: i32 };
const person = try zjson.unmarshal(Person, result.value, allocator);
```

### JSON Pointer (RFC 6901)

```zig
const name = try zjson.getPointer(result.value, "/users/0/name");
const age = try zjson.getPointerAs(i64, result.value, "/users/0/age");
if (zjson.hasPointer(result.value, "/users/1")) { ... }
```

### Marshal

```zig
const json = try zjson.marshalAlloc(person, allocator, .{ .pretty = true });
defer allocator.free(json);
```

### Stream

```zig
// Parse
var parser = zjson.streamParser(allocator, reader, .{});
while (try parser.next()) |token| { ... }

// Write
var writer = zjson.streamWriter(file.writer(), .{});
try writer.beginObject();
try writer.objectField("key");
try writer.write("value");
try writer.endObject();
```

## Options

```zig
// ParseOptions
.allow_comments = false
.allow_trailing_commas = false
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
        return .{ .data = try zjson.toI32(val) };
    }
};
```

## Performance

1.28-2.65x faster than std.json across all workloads.

## License

MIT
