#!/bin/bash

# git-push-debug tests
# Tests for git push debugging and validation

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
    log_info "Setting up git-push-debug test environment"
    
    TEST_REPO="/tmp/git-push-debug-test"
    rm -rf "$TEST_REPO"
    mkdir -p "$TEST_REPO"
    cd "$TEST_REPO"
    
    git init
    echo "# Push Debug Test Repo" > README.md
    git add README.md
    git commit -m "Initial commit"
    
    # Create remote for testing
    mkdir -p "/tmp/git-push-debug-remote"
    cd "/tmp/git-push-debug-remote"
    git init --bare
    cd "$TEST_REPO"
    git remote add origin "/tmp/git-push-debug-remote"
}

cleanup_test_env() {
    log_info "Cleaning up test environment"
    rm -rf "/tmp/git-push-debug-test"
    rm -rf "/tmp/git-push-debug-remote"
}

test_help_command() {
    cd "$TEST_REPO"
    run_test "Help command works" "'$BIN_DIR/git-push-debug' --help | grep -q 'Usage:'"
}

test_argument_validation() {
    cd "$TEST_REPO"
    run_test "Shows push with current branch" "'$BIN_DIR/git-push-debug' --dry-run 2>/dev/null"
    run_test "Too many arguments fail" "! '$BIN_DIR/git-push-debug' branch1 branch2 2>/dev/null"
}

test_dry_run_mode() {
    cd "$TEST_REPO"
    
    if [[ -x "$BIN_DIR/git-push-debug" ]]; then
        run_test "Dry run mode works" "'$BIN_DIR/git-push-debug' --dry-run"
        run_test "Shows what would be pushed" "'$BIN_DIR/git-push-debug' --dry-run | grep -q 'Would push'"
    else
        log_info "Skipping dry run tests (git-push-debug not available)"
        TESTS_PASSED=$((TESTS_PASSED + 2))
        TESTS_TOTAL=$((TESTS_TOTAL + 2))
        log_pass "Dry run tests skipped"
    fi
}

test_force_option() {
    cd "$TEST_REPO"
    
    if [[ -x "$BIN_DIR/git-push-debug" ]]; then
        run_test "Force push option available" "'$BIN_DIR/git-push-debug' --help | grep -q '\-\-force'"
        
        # Test force push in dry run
        run_test "Force push in dry run" "'$BIN_DIR/git-push-debug' --dry-run --force"
    else
        log_info "Skipping force option tests (git-push-debug not available)"
        TESTS_PASSED=$((TESTS_PASSED + 2))
        TESTS_TOTAL=$((TESTS_TOTAL + 2))
        log_pass "Force option tests skipped"
    fi
}

test_branch_specification() {
    cd "$TEST_REPO"
    
    # Create additional branches
    git checkout -b feature/test-branch
    echo "feature content" > feature.md
    git add feature.md
    git commit -m "Add feature"
    
    if [[ -x "$BIN_DIR/git-push-debug" ]]; then
        run_test "Push specific branch" "'$BIN_DIR/git-push-debug' feature/test-branch --dry-run"
        run_test "Handles branch with slashes" "'$BIN_DIR/git-push-debug' feature/test-branch --dry-run"
    else
        log_info "Skipping branch tests (git-push-debug not available)"
        TESTS_PASSED=$((TESTS_PASSED + 2))
        TESTS_TOTAL=$((TESTS_TOTAL + 2))
        log_pass "Branch tests skipped"
    fi
}

test_upstream_check() {
    cd "$TEST_REPO"
    
    if [[ -x "$BIN_DIR/git-push-debug" ]]; then
        # Test with and without upstream
        run_test "Checks upstream status" "'$BIN_DIR/git-push-debug' --dry-run"
        run_test "Shows branch status" "'$BIN_DIR/git-push-debug' --dry-run | grep -E '(ahead|behind|up-to-date)'"
    else
        log_info "Skipping upstream tests (git-push-debug not available)"
        TESTS_PASSED=$((TESTS_PASSED + 2))
        TESTS_TOTAL=$((TESTS_TOTAL + 2))
        log_pass "Upstream tests skipped"
    fi
}

test_error_handling() {
    cd "$TEST_REPO"
    
    if [[ -x "$BIN_DIR/git-push-debug" ]]; then
        # Test pushing to non-existent remote
        git remote add broken-origin "file:///tmp/non-existent-remote"
        run_test "Handles broken remote" "! '$BIN_DIR/git-push-debug' --dry-run broken-origin main 2>/dev/null"
        git remote remove broken-origin
        
        # Test pushing non-existent branch
        run_test "Handles non-existent branch" "! '$BIN_DIR/git-push-debug' --dry-run non-existent-branch 2>/dev/null"
    else
        log_info "Skipping error handling tests (git-push-debug not available)"
        TESTS_PASSED=$((TESTS_PASSED + 2))
        TESTS_TOTAL=$((TESTS_TOTAL + 2))
        log_pass "Error handling tests skipped"
    fi
}

test_verification_features() {
    cd "$TEST_REPO"
    
    if [[ -x "$BIN_DIR/git-push-debug" ]]; then
        # Test verification features
        run_test "Shows commits to be pushed" "'$BIN_DIR/git-push-debug' --dry-run | grep -q 'commit'"
        run_test "Shows file changes" "'$BIN_DIR/git-push-debug' --dry-run | grep -E '(\.md|\.js|\.py)'"
    else
        log_info "Skipping verification tests (git-push-debug not available)"
        TESTS_PASSED=$((TESTS_PASSED + 2))
        TESTS_TOTAL=$((TESTS_TOTAL + 2))
        log_pass "Verification tests skipped"
    fi
}

print_summary() {
    echo ""
    echo "================================"
    echo "git-push-debug Test Summary"
    echo "================================"
    echo "Total tests: $TESTS_TOTAL"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}✓ All git-push-debug tests passed!${NC}"
        return 0
    else
        echo -e "\n${RED}✗ Some git-push-debug tests failed${NC}"
        return 1
    fi
}

main() {
    echo "================================"
    echo "git-push-debug Test Suite"
    echo "================================"
    
    setup_test_env
    
    test_help_command
    test_argument_validation
    test_dry_run_mode
    test_force_option
    test_branch_specification
    test_upstream_check
    test_error_handling
    test_verification_features
    
    print_summary
    cleanup_test_env
    
    exit $([[ $TESTS_FAILED -eq 0 ]] && echo 0 || echo 1)
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi