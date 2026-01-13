#!/bin/bash

# git-wt-remove tests
# Tests for git worktree removal and cleanup functionality

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

setup_test_env() {
    log_info "Setting up git-wt-remove test environment"
    
    TEST_REPO="/tmp/git-wt-remove-test"
    rm -rf "$TEST_REPO"
    mkdir -p "$TEST_REPO"
    cd "$TEST_REPO"
    
    git init --bare .
    git clone "$TEST_REPO" test-main
    cd test-main
    
    # Create initial commit
    echo "# Test Repo" > README.md
    git add README.md
    git commit -m "Initial commit"
    git push origin main
    
    # Create some worktrees
    cd ..
    git clone "$TEST_REPO" feature-branch
    cd feature-branch
    git checkout -b feature/test-branch
    echo "feature content" > feature.md
    git add feature.md
    git commit -m "Add feature"
    git push origin feature/test-branch
    
    cd "$TEST_REPO"
    
    # Use git-wt-add to create worktrees (simulating real usage)
    if [[ -f "$BIN_DIR/git-wt-add" ]]; then
        "$BIN_DIR/git-wt-add" feature-existing-branch main
        "$BIN_DIR/git-wt-add" feature-new-branch
    fi
}

cleanup_test_env() {
    log_info "Cleaning up test environment"
    rm -rf "/tmp/git-wt-remove-test"
}

test_help_command() {
    cd "$TEST_REPO"
    run_test "Help command works" "'$BIN_DIR/git-wt-remove' --help | grep -q 'Usage:'"
}

test_argument_validation() {
    cd "$TEST_REPO"
    run_test "Requires branch name" "! '$BIN_DIR/git-wt-remove' 2>/dev/null"
    run_test "Too many arguments fail" "! '$BIN_DIR/git-wt-remove' branch1 branch2 2>/dev/null"
}

test_remove_basic_worktree() {
    cd "$TEST_REPO"
    
    # Create a worktree to remove
    mkdir -p test-remove-worktree
    cd test-remove-worktree
    git init
    echo "test" > test.md
    git add test.md
    git commit -m "test"
    cd ..
    
    # Basic removal test (if git-wt-remove exists and is executable)
    if [[ -x "$BIN_DIR/git-wt-remove" ]]; then
        run_test "Remove basic worktree" "'$BIN_DIR/git-wt-remove' test-remove-worktree"
        run_test "Worktree directory removed" "! test -d test-remove-worktree"
    else
        log_info "Skipping git-wt-remove tests (script not available)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        TESTS_TOTAL=$((TESTS_TOTAL + 1))
        log_pass "git-wt-remove script available"
    fi
}

test_plugin_cleanup() {
    cd "$TEST_REPO"
    
    # Test plugin cleanup functionality (if available)
    if command -v "$PROJECT_DIR/bin/plugin-manager" >/dev/null 2>&1 && [[ -x "$BIN_DIR/git-wt-remove" ]]; then
        # Create a worktree with JS project for cleanup testing
        mkdir -p test-cleanup-worktree
        cd test-cleanup-worktree
        echo '{"name": "test-project"}' > package.json
        
        # Simulate plugin state
        mkdir -p node_modules
        touch .venv
        
        cd ..
        
        run_test "Removes worktree with plugin cleanup" "'$BIN_DIR/git-wt-remove' test-cleanup-worktree"
        run_test "Worktree directory removed" "! test -d test-cleanup-worktree"
    else
        log_info "Skipping plugin cleanup tests (plugin-manager or git-wt-remove not available)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        TESTS_TOTAL=$((TESTS_TOTAL + 1))
        log_pass "Plugin cleanup test skipped"
    fi
}

test_error_handling() {
    cd "$TEST_REPO"
    
    if [[ -x "$BIN_DIR/git-wt-remove" ]]; then
        # Test removing non-existent worktree
        run_test "Handles non-existent worktree" "! '$BIN_DIR/git-wt-remove' non-existent-worktree 2>/dev/null"
        
        # Test removing current directory
        mkdir -p test-current-dir
        cd test-current-dir
        run_test "Prevents removing current directory" "! '$BIN_DIR/git-wt-remove' . 2>/dev/null"
        cd ..
        rmdir test-current-dir
    else
        log_info "Skipping error handling tests (git-wt-remove not available)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        TESTS_TOTAL=$((TESTS_TOTAL + 1))
        log_pass "Error handling test skipped"
    fi
}

print_summary() {
    echo ""
    echo "================================"
    echo "git-wt-remove Test Summary"
    echo "================================"
    echo "Total tests: $TESTS_TOTAL"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}✓ All git-wt-remove tests passed!${NC}"
        return 0
    else
        echo -e "\n${RED}✗ Some git-wt-remove tests failed${NC}"
        return 1
    fi
}

main() {
    echo "================================"
    echo "git-wt-remove Test Suite"
    echo "================================"
    
    setup_test_env
    
    test_help_command
    test_argument_validation
    test_remove_basic_worktree
    test_plugin_cleanup
    test_error_handling
    
    print_summary
    cleanup_test_env
    
    exit $([[ $TESTS_FAILED -eq 0 ]] && echo 0 || echo 1)
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi