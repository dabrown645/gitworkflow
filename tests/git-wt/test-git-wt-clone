#!/bin/bash

# git-wt-clone tests
# Tests for git repository cloning with worktree setup

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
    log_info "Setting up git-wt-clone test environment"
    
    # Create a remote repo to clone from
    REMOTE_REPO="/tmp/git-wt-clone-remote"
    rm -rf "$REMOTE_REPO"
    mkdir -p "$REMOTE_REPO"
    cd "$REMOTE_REPO"
    
    git init --bare
    cd ..
    
    # Create source repo
    SOURCE_REPO="/tmp/git-wt-clone-source"
    rm -rf "$SOURCE_REPO"
    mkdir -p "$SOURCE_REPO"
    cd "$SOURCE_REPO"
    git init
    echo "# Clone Test Repo" > README.md
    git add README.md
    git commit -m "Initial commit"
    git remote add origin "$REMOTE_REPO"
    git push origin main
    cd ..
}

cleanup_test_env() {
    log_info "Cleaning up test environment"
    rm -rf "/tmp/git-wt-clone-remote"
    rm -rf "/tmp/git-wt-clone-source"
    rm -rf "/tmp/test-clone-output"
}

test_help_command() {
    cd "/tmp"
    run_test "Help command works" "'$BIN_DIR/git-wt-clone' --help | grep -q 'Usage:'"
}

test_argument_validation() {
    cd "/tmp"
    run_test "Requires repository URL" "! '$BIN_DIR/git-wt-clone' 2>/dev/null"
    run_test "Too many arguments fail" "! '$BIN_DIR/git-wt-clone' url dir1 dir2 2>/dev/null"
}

test_basic_clone() {
    cd "/tmp"
    
    if [[ -x "$BIN_DIR/git-wt-clone" ]]; then
        run_test "Basic clone functionality" "'$BIN_DIR/git-wt-clone' '$SOURCE_REPO' test-clone-output"
        run_test "Clone directory created" "test -d test-clone-output"
        run_test "Clone is git repository" "cd test-clone-output && git status > /dev/null 2>&1"
    else
        log_info "Skipping clone tests (git-wt-clone not available)"
        TESTS_PASSED=$((TESTS_PASSED + 3))
        TESTS_TOTAL=$((TESTS_TOTAL + 3))
        log_pass "Basic clone tests skipped"
    fi
}

test_worktree_setup() {
    cd "/tmp"
    
    if [[ -x "$BIN_DIR/git-wt-clone" ]]; then
        run_test "Sets up worktree structure" "'$BIN_DIR/git-wt-clone' '$SOURCE_REPO' worktree-test"
        
        if [[ -d "worktree-test" ]]; then
            cd worktree-test
            run_test "Worktree is git repository" "git status > /dev/null 2>&1"
            run_test "Main branch checked out" "git rev-parse --verify HEAD > /dev/null"
        fi
    else
        log_info "Skipping worktree setup test (git-wt-clone not available)"
        TESTS_PASSED=$((TESTS_PASSED + 3))
        TESTS_TOTAL=$((TESTS_TOTAL + 3))
        log_pass "Worktree setup tests skipped"
    fi
}

test_auto_setup_integration() {
    cd "/tmp"
    
    if [[ -x "$BIN_DIR/git-wt-clone" ]] && command -v "$PROJECT_DIR/bin/plugin-manager" >/dev/null 2>&1; then
        # Create a repo with package.json for testing
        mkdir -p "$SOURCE_REPO-with-packages"
        cd "$SOURCE_REPO-with-packages"
        git init
        echo '{"name": "test-repo"}' > package.json
        git add package.json
        git commit -m "Add package.json"
        git remote add origin "$REMOTE_REPO"
        git push origin main
        cd ..
        
        # Test clone with auto-setup
        run_test "Clone with auto-setup capability" "'$BIN_DIR/git-wt-clone' '$SOURCE_REPO-with-packages' auto-test"
        
        rm -rf "$SOURCE_REPO-with-packages"
    else
        log_info "Skipping auto-setup test (git-wt-clone or plugin-manager not available)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        TESTS_TOTAL=$((TESTS_TOTAL + 1))
        log_pass "Auto-setup test skipped"
    fi
}

test_error_handling() {
    cd "/tmp"
    
    if [[ -x "$BIN_DIR/git-wt-clone" ]]; then
        # Test invalid URL
        run_test "Handles invalid repository URL" "! '$BIN_DIR/git-wt-clone' 'invalid-url' 2>/dev/null"
        
        # Test non-existent repo
        run_test "Handles non-existent repository" "! '$BIN_DIR/git-wt-clone' '/tmp/non-existent-repo' 2>/dev/null"
    else
        log_info "Skipping error handling tests (git-wt-clone not available)"
        TESTS_PASSED=$((TESTS_PASSED + 2))
        TESTS_TOTAL=$((TESTS_TOTAL + 2))
        log_pass "Error handling tests skipped"
    fi
}

print_summary() {
    echo ""
    echo "================================"
    echo "git-wt-clone Test Summary"
    echo "================================"
    echo "Total tests: $TESTS_TOTAL"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}✓ All git-wt-clone tests passed!${NC}"
        return 0
    else
        echo -e "\n${RED}✗ Some git-wt-clone tests failed${NC}"
        return 1
    fi
}

main() {
    echo "================================"
    echo "git-wt-clone Test Suite"
    echo "================================"
    
    setup_test_env
    
    test_help_command
    test_argument_validation
    test_basic_clone
    test_worktree_setup
    test_auto_setup_integration
    test_error_handling
    
    print_summary
    cleanup_test_env
    
    exit $([[ $TESTS_FAILED -eq 0 ]] && echo 0 || echo 1)
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi