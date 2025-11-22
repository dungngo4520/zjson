# Changelog

All notable changes documented here. See [Semantic Versioning](https://semver.org).

## [0.1.0] - 2025-11-22

### Core Features

- Arena-based JSON parser
- Compile-time & runtime marshal (Zig structs → JSON)
- Unmarshal (JSON → Zig structs) with type inference
- Streaming parser for large files (token-based)
- Streaming writer for incremental JSON generation

### API

- `parse()` - Fast arena-backed parsing
- `marshal()` / `marshalAlloc()` - Serialization with custom hooks
- `unmarshal()` / `unmarshalWithCustom()` - Deserialization
- `streamParser()` / `streamWriter()` - Memory-efficient streaming
- Value helpers: converters, accessors, utilities
- Error reporting: line/column info + visual indicators

### Options

- Parse: `allow_comments`, `allow_trailing_commas`
- Marshal: `pretty`, `indent`, `omit_null`, `sort_keys`

### Quality

- JSON Test Suite integration

### Known Limitations

- No JSON Pointer/JSONPath queries
- No JSON Schema validation
- No JSON Patch support
- Numbers stored as strings (intentional, for precision)

[0.1.0]: https://github.com/dungngo4520/zjson/releases/tag/v0.1.0
