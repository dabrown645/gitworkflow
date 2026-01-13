# Git Workflow Tools Test Suite

This directory contains comprehensive tests for all git-wt* and git-push* scripts.

## Test Structure

```
tests/
├── run-all-tests.sh           # Master test runner
├── git-wt/                   # Individual git worktree tests
│   ├── test-git-wt-add.sh
│   ├── test-git-wt-remove.sh
│   ├── test-git-wt-status.sh
│   ├── test-git-wt-clone.sh
│   └── test-git-wt-clone-fork.sh
├── git-push/                  # Git push tests
│   └── test-git-push-debug.sh
├── unit/                     # Core functionality tests
│   └── test-core-functions.sh
├── integration/              # End-to-end workflow tests
│   └── test-workflow.sh
└── test-plugins.sh           # Plugin system tests
```

## Running Tests

### Master Test Runner

The `run-all-tests.sh` script is the primary way to run tests:

```bash
# Run all tests (default)
./tests/run-all-tests.sh

# Run specific test suites
./tests/run-all-tests.sh git-wt-add plugins unit

# List available test suites
./tests/run-all-tests.sh --list

# Clean artifacts and run tests
./tests/run-all-tests.sh --clean

# Show help
./tests/run-all-tests.sh --help
```

### Individual Test Suites

You can also run individual test suites directly:

```bash
# git worktree tests
./tests/git-wt/test-git-wt-add.sh
./tests/git-wt/test-git-wt-remove.sh
./tests/git-wt/test-git-wt-status.sh
./tests/git-wt/test-git-wt-clone.sh
./tests/git-wt/test-git-wt-clone-fork.sh

# git push tests
./tests/git-push/test-git-push-debug.sh

# Core functionality tests
./tests/unit/test-core-functions.sh

# Integration tests
./tests/integration/test-workflow.sh

# Plugin system tests
./tests/test-plugins.sh
```

## Test Coverage

### git-wt-add Tests
- Help command and argument parsing
- Worktree creation and branch setup
- CLI flags (--auto-setup/--no-auto-setup)
- Plugin auto-setup integration
- Error handling for duplicates and invalid inputs

### git-wt-remove Tests
- Worktree removal and cleanup
- Plugin cleanup integration
- Error handling for invalid worktrees
- Force removal options

### git-wt-status Tests
- Worktree listing and status display
- Multiple worktree handling
- Output format validation
- Error handling for non-git directories

### git-wt-clone Tests
- Repository cloning and worktree setup
- Remote URL validation
- Auto-setup integration
- Error handling for invalid repositories

### git-wt-clone-fork Tests
- Fork cloning with upstream setup
- Remote configuration (origin/upstream)
- Worktree creation from forks
- Error handling

### git-push-debug Tests
- Dry run mode functionality
- Branch specification and force options
- Upstream status checking
- Verification features

### Unit Tests
- Script executability and help functionality
- Plugin manager command availability
- Configuration system testing
- Error handling validation
- File system operations
- Git operations

### Integration Tests
- Complete end-to-end workflows
- Clone → Add → Status → Push → Remove cycles
- Plugin integration throughout workflows
- Multi-repository scenarios

### Plugin Tests
- Plugin manager functionality
- Language detection (JavaScript, Python, Rust, UV)
- Plugin enable/disable operations
- Auto-setup and cleanup
- Configuration parsing

## Test Environment

Tests create temporary files and directories under `/tmp/`:
- `/tmp/git-wt-*` - git worktree tests
- `/tmp/test-*` - unit and integration tests
- `/tmp/plugin-test-*` - plugin tests

All artifacts are automatically cleaned up after each test run.

## Output Format

Test results use color-coded output:
- 🟡 [INFO] - Information messages
- ✅ [PASS] - Successful test
- ❌ [FAIL] - Failed test
- 🟦 [SUITE] - Test suite information
- 🟩 [SUCCESS] - Suite completion
- 🔴 [ERROR] - Error messages

## Dependencies

All test scripts require:
- All git-wt* and git-push* scripts in `bin/`
- `plugin-manager` script in `bin/`
- Git installed and configured
- Standard Unix utilities (bash, grep, sed, etc.)

## Troubleshooting

### Tests Fail with "script not found"
- Ensure you're running from project root
- Check that all scripts exist in `bin/`
- Verify scripts are executable: `chmod +x bin/*`

### Tests Fail with Permission Errors
- Ensure test directories are writable
- Check temporary directory access: `ls -la /tmp/`

### Plugin Tests Fail
- Verify plugin-manager is accessible
- Check plugin files exist in `plugins/`
- Ensure dependencies (node, python, cargo) are installed

### Integration Tests Fail
- Check Git configuration: `git config --list`
- Verify remote connectivity
- Clean up any existing test artifacts

## Contributing

When adding new tests:

1. Follow existing naming conventions
2. Include setup/cleanup functions
3. Use color-coded output
4. Test both success and failure cases
5. Update this README with new test coverage

## Continuous Integration

These tests are designed to run in CI/CD environments:
- Self-contained with no external dependencies
- Automatic cleanup of test artifacts
- Clear exit codes for test status
- Comprehensive error reporting