# Contributing to zjson

Thank you for your interest in contributing to zjson! We welcome contributions of all kinds.

## How to Contribute

### Reporting Bugs

- Check if the bug has already been reported in Issues
- Provide a clear description of the bug
- Include minimal reproducible example if possible
- Specify your Zig version (`zig version`)

### Suggesting Enhancements

- Use Issues to suggest new features
- Provide clear use cases and examples
- Discuss before starting major work

### Pull Requests

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Make your changes
4. Ensure tests pass: `zig build test`
5. Format code: `zig fmt src/ tests/ examples/ build.zig`
6. Commit with clear messages
7. Push to your fork and open a Pull Request

## Code Guidelines

- Follow Zig naming conventions
- Write tests for new functionality
- Keep functions focused and well-documented
- Use meaningful variable names
- Ensure code is properly formatted with `zig fmt`

## Testing

Run tests before submitting:

```bash
zig build test        # Run all tests
zig build examples    # Build examples
zig build            # Full build
```

## Questions?

Feel free to open an Issue with the `question` label or discussion topic.

Thank you for contributing! 🎉
