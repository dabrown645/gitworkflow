#!/bin/bash

# Unit tests for core functionality
# Tests individual functions and components

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
BIN_DIR="$PROJECT_DIR/bin"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

log_info() { echo -e "${YELLOW}[INFO]${NC} $1"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; }

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    log_info "Running: $test_name"
    
    if eval "$test_command" > /dev/null 2>&1; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_pass "$test_name"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_fail "$test_name"
        echo "  Command: $test_command"
        return 1
    fi
}

# Test script executability
test_script_executability() {
    run_test "git-wt-add is executable" "test -x '$BIN_DIR/git-wt-add'"
    run_test "git-wt-remove is executable" "test -x '$BIN_DIR/git-wt-remove'"
    run_test "git-wt-status is executable" "test -x '$BIN_DIR/git-wt-status'"
    run_test "git-wt-clone is executable" "test -x '$BIN_DIR/git-wt-clone'"
    run_test "git-wt-clone-fork is executable" "test -x '$BIN_DIR/git-wt-clone-fork'"
    run_test "git-push-debug is executable" "test -x '$BIN_DIR/git-push-debug'"
    run_test "plugin-manager is executable" "test -x '$PROJECT_DIR/bin/plugin-manager'"
}

# Test script help functionality
test_help_functionality() {
    run_test "git-wt-add has help" "'$BIN_DIR/git-wt-add' --help | grep -q 'Usage:'"
    run_test "git-wt-remove has help" "'$BIN_DIR/git-wt-remove' --help | grep -q 'Usage:'"
    run_test "git-wt-status runs without help flag" "'$BIN_DIR/git-wt-status' > /dev/null 2>&1"
    run_test "git-wt-clone has help" "'$BIN_DIR/git-wt-clone' --help | grep -q 'Usage:'"
    run_test "git-wt-clone-fork has help" "'$BIN_DIR/git-wt-clone-fork' --help | grep -q 'Usage:'"
    run_test "git-push-debug has help" "'$BIN_DIR/git-push-debug' --help | grep -q 'Usage:'"
    run_test "plugin-manager has help" "'$PROJECT_DIR/bin/plugin-manager' help | grep -q 'Usage:'"
}

# Test plugin manager functionality
test_plugin_manager_commands() {
    run_test "plugin-manager list-available" "'$PROJECT_DIR/bin/plugin-manager' list-available"
    run_test "plugin-manager list-enabled" "'$PROJECT_DIR/bin/plugin-manager' list-enabled"
    run_test "plugin-manager can enable plugin" "'$PROJECT_DIR/bin/plugin-manager' enable javascript"
    run_test "plugin-manager can disable plugin" "'$PROJECT_DIR/bin/plugin-manager' disable javascript"
}

# Test configuration system
test_configuration_system() {
    # Create test config
    TEST_CONFIG="/tmp/test-git-workflow-config"
    rm -rf "$TEST_CONFIG"
    mkdir -p "$TEST_CONFIG/gitworkflow/plugins/config"
    echo 'auto_setup: true' > "$TEST_CONFIG/gitworkflow/plugins/config/default.yaml"
    
    # Test configuration reading
    export XDG_CONFIG_DIR="$TEST_CONFIG"
    
    run_test "XDG config directory creation" "test -d '$TEST_CONFIG/gitworkflow'"
    run_test "Plugin config directory exists" "test -d '$TEST_CONFIG/gitworkflow/plugins'"
    run_test "Default config file exists" "test -f '$TEST_CONFIG/gitworkflow/plugins/config/default.yaml'"
    
    unset XDG_CONFIG_DIR
    rm -rf "$TEST_CONFIG"
}

# Test error handling
test_error_handling() {
    # Test invalid arguments
    run_test "git-wt-add rejects no arguments" "! '$BIN_DIR/git-wt-add' 2>/dev/null"
    run_test "git-wt-remove rejects no arguments" "! '$BIN_DIR/git-wt-remove' 2>/dev/null"
    run_test "git-wt-clone rejects no arguments" "! '$BIN_DIR/git-wt-clone' 2>/dev/null"
    run_test "git-wt-clone-fork rejects no arguments" "! '$BIN_DIR/git-wt-clone-fork' 2>/dev/null"
    run_test "plugin-manager rejects invalid command" "! '$PROJECT_DIR/bin/plugin-manager' invalid-command 2>/dev/null"
}

# Test file system operations
test_file_operations() {
    TEST_DIR="/tmp/test-file-ops"
    rm -rf "$TEST_DIR"
    mkdir -p "$TEST_DIR"
    
    # Test creating and removing files
    echo "test" > "$TEST_DIR/test.txt"
    run_test "File creation" "test -f '$TEST_DIR/test.txt'"
    
    mkdir -p "$TEST_DIR/subdir"
    run_test "Directory creation" "test -d '$TEST_DIR/subdir'"
    
    rm -rf "$TEST_DIR"
    run_test "Directory removal" "! test -d '$TEST_DIR'"
}

# Test git operations
test_git_operations() {
    TEST_GIT="/tmp/test-git-ops"
    rm -rf "$TEST_GIT"
    mkdir -p "$TEST_GIT"
    cd "$TEST_GIT"
    
    # Test git initialization
    run_test "Git init" "git init > /dev/null 2>&1"
    
    echo "# Test" > README.md
    git add README.md > /dev/null 2>&1
    git commit -m "test" > /dev/null 2>&1
    
    run_test "Git commit" "test -d .git"
    
    cd /tmp
    rm -rf "$TEST_GIT"
}

print_summary() {
    echo ""
    echo "================================"
    echo "Unit Tests Summary"
    echo "================================"
    echo "Total tests: $TESTS_TOTAL"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}✓ All unit tests passed!${NC}"
        return 0
    else
        echo -e "\n${RED}✗ Some unit tests failed${NC}"
        return 1
    fi
}

main() {
    echo "================================"
    echo "Unit Tests Suite"
    echo "================================"
    
    test_script_executability
    test_help_functionality
    test_plugin_manager_commands
    test_configuration_system
    test_error_handling
    test_file_operations
    test_git_operations
    
    print_summary
    
    exit $([[ $TESTS_FAILED -eq 0 ]] && echo 0 || echo 1)
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi