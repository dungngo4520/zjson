# JSON Test Suite

This directory contains the [JSONTestSuite](https://github.com/nst/JSONTestSuite) as a git submodule.

## Running the Tests

### Using Zig build (recommended)

```bash
zig build test-suite
```

### Using Python directly

```bash
cd tests/json_test_suite
python3 run_json_test_suite.py
```

Results will be displayed in the terminal and saved to `tests/json_test_suite/test_suite_results.json`.

## Test Categories

- `y_*.json` - Must be accepted by a valid JSON parser
- `n_*.json` - Must be rejected by a valid JSON parser
- `i_*.json` - Implementation-defined (parser may accept or reject)

## Current Results

Run the test suite to see current pass rates for:

- Must Accept tests
- Must Reject tests
- Implementation Defined tests
