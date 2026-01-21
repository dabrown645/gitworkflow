#!/bin/bash

# git-wt-add tests
# Tests for git worktree creation and auto-setup functionality

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

# Test tracking
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

# Setup test environment
setup_test_env() {
    log_info "Setting up git-wt-add test environment"
    
    # Create test git repo
    TEST_REPO="/tmp/git-wt-add-test"
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
    
    cd ..
    rm -rf test-main
}

# Cleanup test environment
cleanup_test_env() {
    log_info "Cleaning up test environment"
    rm -rf "/tmp/git-wt-add-test"
}

test_help_command() {
    run_test "Help command works" "'$BIN_DIR/git-wt-add' --help | grep -q 'Usage:'"
}

test_argument_parsing() {
    run_test "Requires branch name" "! '$BIN_DIR/git-wt-add' 2>/dev/null"
    run_test "Too many arguments fail" "! '$BIN_DIR/git-wt-add' branch1 branch2 extra 2>/dev/null"
}

test_worktree_creation() {
    cd "$TEST_REPO"
    run_test "Create basic worktree" "'$BIN_DIR/git-wt-add' feature-test-branch"
    run_test "Worktree directory exists" "test -d feature-test-branch"
    run_test "Worktree is git worktree" "cd feature-test-branch && git status > /dev/null 2>&1"
}

test_branch_creation() {
    cd "$TEST_REPO"
    run_test "Create worktree from branch" "'$BIN_DIR/git-wt-add' feature-new-branch main"
    run_test "New branch exists" "cd feature-new-branch && git rev-parse --verify HEAD > /dev/null"
}

test_cli_flags() {
    cd "$TEST_REPO"
    run_test "--auto-setup flag recognized" "'$BIN_DIR/git-wt-add' --help | grep -q '\-\-auto-setup'"
    run_test "--no-auto-setup flag recognized" "'$BIN_DIR/git-wt-add' --help | grep -q '\-\-no-auto-setup'"
    run_test "Help flag works" "'$BIN_DIR/git-wt-add' --help > /dev/null"
}

test_auto_setup_integration() {
    cd "$TEST_REPO"
    
    # Create a JS project in new worktree
    run_test "Create JS worktree" "'$BIN_DIR/git-wt-add' feature-js-project --auto-setup"
    
    if [[ -d "feature-js-project" ]]; then
        echo '{"name": "test-js-project"}' > feature-js-project/package.json
        
        # Test that plugin-manager can be called (won't fail if no package managers)
        if command -v "$PROJECT_DIR/bin/plugin-manager" >/dev/null 2>&1; then
            log_pass "Plugin manager accessible for auto-setup"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            log_fail "Plugin manager not accessible"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
        TESTS_TOTAL=$((TESTS_TOTAL + 1))
    fi
}

test_error_handling() {
    cd "$TEST_REPO"
    
    # Test duplicate worktree
    '$BIN_DIR/git-wt-add' duplicate-branch
    run_test "Prevents duplicate worktree" "! '$BIN_DIR/git-wt-add' duplicate-branch 2>/dev/null"
    
    # Test non-existent base branch
    run_test "Handles non-existent base branch" "! '$BIN_DIR/git-wt-add' new-branch non-existent-branch 2>/dev/null"
}

print_summary() {
    echo ""
    echo "================================"
    echo "git-wt-add Test Summary"
    echo "================================"
    echo "Total tests: $TESTS_TOTAL"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}✓ All git-wt-add tests passed!${NC}"
        return 0
    else
        echo -e "\n${RED}✗ Some git-wt-add tests failed${NC}"
        return 1
    fi
}

main() {
    echo "================================"
    echo "git-wt-add Test Suite"
    echo "================================"
    
    setup_test_env
    
    test_help_command
    test_argument_parsing
    test_worktree_creation
    test_branch_creation
    test_cli_flags
    test_auto_setup_integration
    test_error_handling
    
    print_summary
    cleanup_test_env
    
    exit $([[ $TESTS_FAILED -eq 0 ]] && echo 0 || echo 1)
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi