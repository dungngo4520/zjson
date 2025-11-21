# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Renamed `stringify()` to `marshal()` and `stringifyAlloc()` to `marshalAlloc()` for better API coherence with `unmarshal()`
- Renamed `StringifyOptions` to `MarshalOptions`
- Renamed `stringifyWithCustom()` to `marshalWithCustom()`

### Added

- Initial public release of zjson
- Compile-time JSON serialization with `stringify()`
- Runtime JSON parsing with `parse()`
- Support for all JSON types: null, bool, number, string, array, object
- String escaping with full JSON spec compliance
- Optional field omission (omitempty)
- Enum serialization support
- Memory management with allocator support
- Comprehensive test suite with 15+ tests
- CI/CD with GitHub Actions
- Auto-discovery build system for tests and examples
- Professional documentation and examples
- MIT License
- Contribution guidelines

## [0.1.0] - 2025-11-19

### Initial Release

- Initial alpha release
- Core stringify and parse functionality
- Basic documentation

[Unreleased]: https://github.com/username/zjson/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/username/zjson/releases/tag/v0.1.0
