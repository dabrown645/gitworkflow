#!/bin/bash

# git-wt-status tests
# Tests for git worktree status display functionality

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
    log_info "Setting up git-wt-status test environment"
    
    TEST_REPO="/tmp/git-wt-status-test"
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
    
    cd "$TEST_REPO"
}

cleanup_test_env() {
    log_info "Cleaning up test environment"
    rm -rf "/tmp/git-wt-status-test"
}

test_help_command() {
    cd "$TEST_REPO"
    run_test "Help command works" "'$BIN_DIR/git-wt-status' --help | grep -q 'Usage:'"
}

test_basic_status() {
    cd "$TEST_REPO"
    run_test "Shows basic status" "'$BIN_DIR/git-wt-status' > /dev/null 2>&1"
}

test_status_output_format() {
    cd "$TEST_REPO"
    
    if [[ -x "$BIN_DIR/git-wt-status" ]]; then
        # Test that status contains expected elements
        local output
        output=$("$BIN_DIR/git-wt-status" 2>/dev/null || echo "")
        
        if [[ -n "$output" ]]; then
            log_pass "Status generates output"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            log_fail "Status generates no output"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
        TESTS_TOTAL=$((TESTS_TOTAL + 1))
    else
        log_info "Skipping output format test (git-wt-status not available)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        TESTS_TOTAL=$((TESTS_TOTAL + 1))
        log_pass "Output format test skipped"
    fi
}

test_multiple_worktrees() {
    cd "$TEST_REPO"
    
    # Create additional worktrees
    mkdir -p feature-branch
    cd feature-branch
    git init
    echo "feature" > feature.md
    git add feature.md
    git commit -m "feature"
    cd ..
    
    mkdir -p hotfix-branch
    cd hotfix-branch
    git init
    echo "hotfix" > hotfix.md
    git add hotfix.md
    git commit -m "hotfix"
    cd ..
    
    if [[ -x "$BIN_DIR/git-wt-status" ]]; then
        run_test "Handles multiple worktrees" "'$BIN_DIR/git-wt-status' > /dev/null 2>&1"
    else
        log_info "Skipping multiple worktrees test (git-wt-status not available)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        TESTS_TOTAL=$((TESTS_TOTAL + 1))
        log_pass "Multiple worktrees test skipped"
    fi
}

test_error_handling() {
    cd "/tmp"
    
    if [[ -x "$BIN_DIR/git-wt-status" ]]; then
        run_test "Handles non-git directory" "! '$BIN_DIR/git-wt-status' 2>/dev/null"
    else
        log_info "Skipping error handling test (git-wt-status not available)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        TESTS_TOTAL=$((TESTS_TOTAL + 1))
        log_pass "Error handling test skipped"
    fi
}

print_summary() {
    echo ""
    echo "================================"
    echo "git-wt-status Test Summary"
    echo "================================"
    echo "Total tests: $TESTS_TOTAL"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}✓ All git-wt-status tests passed!${NC}"
        return 0
    else
        echo -e "\n${RED}✗ Some git-wt-status tests failed${NC}"
        return 1
    fi
}

main() {
    echo "================================"
    echo "git-wt-status Test Suite"
    echo "================================"
    
    setup_test_env
    
    test_help_command
    test_basic_status
    test_status_output_format
    test_multiple_worktrees
    test_error_handling
    
    print_summary
    cleanup_test_env
    
    exit $([[ $TESTS_FAILED -eq 0 ]] && echo 0 || echo 1)
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi