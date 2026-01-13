# Plugin System Tests

This directory contains tests for the Git Worktree Plugin System.

## Running Tests

```bash
# From the project root
./tests/test-plugins.sh

# Or directly from the tests directory
cd tests && ./test-plugins.sh
```

## Test Coverage

- **Plugin Manager Tests**: Basic commands (help, list, enable, disable)
- **Plugin Detection Tests**: JavaScript, Python (pip/uv/poetry/pipenv), Rust
- **Plugin Setup Tests**: Auto-setup, manual setup, status reporting
- **Integration Tests**: Full workflow from detection to cleanup
- **Cleanup Tests**: Proper cleanup of worktree resources

## Test Environment

Tests create temporary projects in `/tmp/git-worktree-plugin-tests/` and clean up automatically after completion.

## Results

All tests should pass (17 tests total). If any tests fail, check the output for specific error details.