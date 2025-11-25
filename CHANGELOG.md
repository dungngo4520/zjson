# Changelog

## [1.0.0] - 2025-11-26

### Added

- Safety limits: max_depth (128), max_document_size (10MB)
- Duplicate key policies: keep_last, keep_first, reject
- Number overflow detection
- Error hints with line/column info
- HashMap/ArrayList marshal/unmarshal
- Marshal options: use_tabs, compact_arrays, line_ending, sort_keys
- Custom enum serialization via marshal()/unmarshal() methods
- Streaming parser and writer

### Performance

1.28-2.65x faster than std.json

### Notes

- No breaking changes from v0.1.0
- 111+ tests passing

## [0.1.0] - 2025-11-22

Initial release.

- Arena-based JSON parser
- Compile-time and runtime marshaling
- Unmarshal to typed structs
- Streaming parse/write
- Comments and trailing commas support

[1.0.0]: https://github.com/dungngo4520/zjson/releases/tag/v1.0.0
[0.1.0]: https://github.com/dungngo4520/zjson/releases/tag/v0.1.0
