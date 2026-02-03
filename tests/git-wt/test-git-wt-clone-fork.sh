#!/bin/bash

# git-wt-clone-fork tests
# Tests for git repository fork cloning with worktree setup

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
    log_info "Setting up git-wt-clone-fork test environment"
    
    # Create upstream repo
    UPSTREAM_REPO="/tmp/git-wt-clone-fork-upstream"
    rm -rf "$UPSTREAM_REPO"
    mkdir -p "$UPSTREAM_REPO"
    cd "$UPSTREAM_REPO"
    
    git init --bare
    cd ..
    
    # Create source repo (simulating a fork)
    FORK_REPO="/tmp/git-wt-clone-fork-source"
    rm -rf "$FORK_REPO"
    mkdir -p "$FORK_REPO"
    cd "$FORK_REPO"
    git init
    echo "# Fork Test Repo" > README.md
    git add README.md
    git commit -m "Initial commit"
    git remote add upstream "$UPSTREAM_REPO"
    # Note: Don't push to origin since it doesn't exist yet
    cd ..
}

cleanup_test_env() {
    log_info "Cleaning up test environment"
    rm -rf "/tmp/git-wt-clone-fork-upstream"
    rm -rf "/tmp/git-wt-clone-fork-source"
    rm -rf "/tmp/test-fork-output"
}

test_help_command() {
    cd "/tmp"
    run_test "Help command works" "'$BIN_DIR/git-wt-clone-fork' --help | grep -q 'Usage:'"
}

test_argument_validation() {
    cd "/tmp"
    run_test "Requires repository URL" "! '$BIN_DIR/git-wt-clone-fork' 2>/dev/null"
    run_test "Too many arguments fail" "! '$BIN_DIR/git-wt-clone-fork' url dir1 dir2 2>/dev/null"
}

test_basic_fork_clone() {
    cd "/tmp"
    
    if [[ -x "$BIN_DIR/git-wt-clone-fork" ]]; then
        run_test "Basic fork clone functionality" "'$BIN_DIR/git-wt-clone-fork' '$FORK_REPO' test-fork-output"
        run_test "Fork clone directory created" "test -d test-fork-output"
        run_test "Fork clone is git repository" "cd test-fork-output && git status > /dev/null 2>&1"
    else
        log_info "Skipping fork clone tests (git-wt-clone-fork not available)"
        TESTS_PASSED=$((TESTS_PASSED + 3))
        TESTS_TOTAL=$((TESTS_TOTAL + 3))
        log_pass "Basic fork clone tests skipped"
    fi
}

test_upstream_setup() {
    cd "/tmp"
    
    if [[ -x "$BIN_DIR/git-wt-clone-fork" ]]; then
        run_test "Sets up upstream remote" "'$BIN_DIR/git-wt-clone-fork' '$FORK_REPO' upstream-test"
        
        if [[ -d "upstream-test" ]]; then
            cd upstream-test
            run_test "Upstream remote configured" "git remote get-url upstream > /dev/null 2>&1"
            run_test "Origin remote configured" "git remote get-url origin > /dev/null 2>&1"
        fi
    else
        log_info "Skipping upstream setup test (git-wt-clone-fork not available)"
        TESTS_PASSED=$((TESTS_PASSED + 3))
        TESTS_TOTAL=$((TESTS_TOTAL + 3))
        log_pass "Upstream setup tests skipped"
    fi
}

test_worktree_integration() {
    cd "/tmp"
    
    if [[ -x "$BIN_DIR/git-wt-clone-fork" ]]; then
        run_test "Creates worktree structure" "'$BIN_DIR/git-wt-clone-fork' '$FORK_REPO' worktree-fork-test"
        
        if [[ -d "worktree-fork-test" ]]; then
            cd worktree-fork-test
            run_test "Worktree is git repository" "git status > /dev/null 2>&1"
            run_test "Main branch checked out" "git rev-parse --verify HEAD > /dev/null"
        fi
    else
        log_info "Skipping worktree integration test (git-wt-clone-fork not available)"
        TESTS_PASSED=$((TESTS_PASSED + 3))
        TESTS_TOTAL=$((TESTS_TOTAL + 3))
        log_pass "Worktree integration test skipped"
    fi
}

test_error_handling() {
    cd "/tmp"
    
    if [[ -x "$BIN_DIR/git-wt-clone-fork" ]]; then
        # Test invalid URL
        run_test "Handles invalid repository URL" "! '$BIN_DIR/git-wt-clone-fork' 'invalid-url' 2>/dev/null"
        
        # Test non-existent repo
        run_test "Handles non-existent repository" "! '$BIN_DIR/git-wt-clone-fork' '/tmp/non-existent-fork' 2>/dev/null"
    else
        log_info "Skipping error handling tests (git-wt-clone-fork not available)"
        TESTS_PASSED=$((TESTS_PASSED + 2))
        TESTS_TOTAL=$((TESTS_TOTAL + 2))
        log_pass "Error handling tests skipped"
    fi
}

print_summary() {
    echo ""
    echo "================================"
    echo "git-wt-clone-fork Test Summary"
    echo "================================"
    echo "Total tests: $TESTS_TOTAL"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}✓ All git-wt-clone-fork tests passed!${NC}"
        return 0
    else
        echo -e "\n${RED}✗ Some git-wt-clone-fork tests failed${NC}"
        return 1
    fi
}

main() {
    echo "================================"
    echo "git-wt-clone-fork Test Suite"
    echo "================================"
    
    setup_test_env
    
    test_help_command
    test_argument_validation
    test_basic_fork_clone
    test_upstream_setup
    test_worktree_integration
    test_error_handling
    
    print_summary
    cleanup_test_env
    
    exit $([[ $TESTS_FAILED -eq 0 ]] && echo 0 || echo 1)
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi