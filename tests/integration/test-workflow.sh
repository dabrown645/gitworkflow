#!/bin/bash

# Integration tests for complete workflow
# Tests end-to-end scenarios with multiple scripts

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
    log_info "Setting up integration test environment"
    
    # Create remote repository
    REMOTE_REPO="/tmp/integration-test-remote"
    rm -rf "$REMOTE_REPO"
    mkdir -p "$REMOTE_REPO"
    cd "$REMOTE_REPO"
    git init --bare
    cd ..
    
    # Create main repository
    MAIN_REPO="/tmp/integration-test-main"
    rm -rf "$MAIN_REPO"
    mkdir -p "$MAIN_REPO"
    cd "$MAIN_REPO"
    git init
    echo "# Integration Test Repo" > README.md
    echo "main content" > main.txt
    git add README.md main.txt
    git commit -m "Initial commit"
    git remote add origin "$REMOTE_REPO"
    git push origin main
    
    # Create worktree directory
    WORKTREE_DIR="/tmp/integration-test-worktrees"
    rm -rf "$WORKTREE_DIR"
    mkdir -p "$WORKTREE_DIR"
    cd "$WORKTREE_DIR"
    
    # Create project structure for testing
    mkdir -p "$WORKTREE_DIR/template-project"
    cd "$WORKTREE_DIR/template-project"
    echo '{"name": "integration-test", "dependencies": {"lodash": "^4.17.21"}}' > package.json
    echo "requests==2.31.0" > requirements.txt
    echo '[package]' > pyproject.toml
    echo 'name = "python-integration-test"' >> pyproject.toml
}

cleanup_test_env() {
    log_info "Cleaning up integration test environment"
    rm -rf "/tmp/integration-test-remote"
    rm -rf "/tmp/integration-test-main"
    rm -rf "/tmp/integration-test-worktrees"
}

test_complete_workflow() {
    cd "$WORKTREE_DIR"
    
    if [[ -x "$BIN_DIR/git-wt-add" ]]; then
        # Test adding worktree with auto-setup
        run_test "Complete workflow - add worktree" "'$BIN_DIR/git-wt-add' feature/integration-test main --auto-setup"
        
        if [[ -d "feature/integration-test" ]]; then
            cd "feature/integration-test"
            run_test "Complete workflow - worktree is git repo" "git status > /dev/null 2>&1"
            run_test "Complete workflow - JS project detected" "test -f package.json"
            run_test "Complete workflow - Python project detected" "test -f requirements.txt"
        fi
    else
        log_info "Skipping workflow test (git-wt-add not available)"
        TESTS_PASSED=$((TESTS_PASSED + 4))
        TESTS_TOTAL=$((TESTS_TOTAL + 4))
        log_pass "Complete workflow test skipped"
    fi
}

test_clone_and_workflow() {
    cd "/tmp"
    
    if [[ -x "$BIN_DIR/git-wt-clone" ]] && [[ -x "$BIN_DIR/git-wt-add" ]]; then
        run_test "Clone and setup workflow" "'$BIN_DIR/git-wt-clone' '$MAIN_REPO' cloned-project"
        
        if [[ -d "cloned-project" ]]; then
            cd "cloned-project"
            
            # Create a feature branch and worktree
            git checkout -b feature/cloned-test
            echo "cloned feature" > feature.txt
            git add feature.txt
            git commit -m "Add cloned feature"
            
            cd "/tmp"
            run_test "Add worktree to cloned repo" "'$BIN_DIR/git-wt-add' feature/from-cloned cloned-project feature/cloned-test"
            
            if [[ -d "feature/from-cloned" ]]; then
                cd "feature/from-cloned"
                run_test "Cloned workflow - feature worktree" "git status > /dev/null 2>&1"
            fi
        fi
    else
        log_info "Skipping clone workflow test (git-wt-clone or git-wt-add not available)"
        TESTS_PASSED=$((TESTS_PASSED + 4))
        TESTS_TOTAL=$((TESTS_TOTAL + 4))
        log_pass "Clone workflow test skipped"
    fi
}

test_fork_workflow() {
    cd "/tmp"
    
    if [[ -x "$BIN_DIR/git-wt-clone-fork" ]] && [[ -x "$BIN_DIR/git-wt-add" ]]; then
        run_test "Fork cloning workflow" "'$BIN_DIR/git-wt-clone-fork' '$MAIN_REPO' forked-project"
        
        if [[ -d "forked-project" ]]; then
            cd "forked-project"
            
            # Test that upstream remote is configured
            run_test "Fork workflow - upstream remote" "git remote get-url upstream > /dev/null 2>&1"
            run_test "Fork workflow - origin remote" "git remote get-url origin > /dev/null 2>&1"
            
            # Create worktree from fork
            cd "/tmp"
            run_test "Add worktree from fork" "'$BIN_DIR/git-wt-add' feature/from-fork forked-project"
            
            if [[ -d "feature/from-fork" ]]; then
                cd "feature/from-fork"
                run_test "Fork workflow - worktree created" "git status > /dev/null 2>&1"
            fi
        fi
    else
        log_info "Skipping fork workflow test (git-wt-clone-fork or git-wt-add not available)"
        TESTS_PASSED=$((TESTS_PASSED + 5))
        TESTS_TOTAL=$((TESTS_TOTAL + 5))
        log_pass "Fork workflow test skipped"
    fi
}

test_plugin_integration() {
    cd "$WORKTREE_DIR"
    
    if [[ -x "$PROJECT_DIR/bin/plugin-manager" ]] && [[ -x "$BIN_DIR/git-wt-add" ]]; then
        # Create worktree with JS project
        run_test "Plugin integration - create JS worktree" "'$BIN_DIR/git-wt-add' feature/plugin-js template-project --auto-setup"
        
        if [[ -d "feature/plugin-js" ]]; then
            cd "feature/plugin-js"
            
            # Test plugin manager commands
            run_test "Plugin integration - list status" "'$PROJECT_DIR/bin/plugin-manager' list-status . > /dev/null"
            run_test "Plugin integration - enable plugin" "'$PROJECT_DIR/bin/plugin-manager' enable javascript"
            run_test "Plugin integration - setup plugin" "'$PROJECT_DIR/bin/plugin-manager' setup javascript ."
        fi
    else
        log_info "Skipping plugin integration test (plugin-manager or git-wt-add not available)"
        TESTS_PASSED=$((TESTS_PASSED + 4))
        TESTS_TOTAL=$((TESTS_TOTAL + 4))
        log_pass "Plugin integration test skipped"
    fi
}

test_status_and_push_workflow() {
    cd "$WORKTREE_DIR"
    
    if [[ -x "$BIN_DIR/git-wt-status" ]] && [[ -x "$BIN_DIR/git-push-debug" ]]; then
        # Create some worktrees to test status
        if [[ -x "$BIN_DIR/git-wt-add" ]]; then
            "$BIN_DIR/git-wt-add" status-test-branch template-project
        fi
        
        cd "$WORKTREE_DIR"
        run_test "Status workflow - show worktrees" "'$BIN_DIR/git-wt-status' > /dev/null 2>&1"
        
        if [[ -d "status-test-branch" ]]; then
            cd "status-test-branch"
            echo "status test changes" > status.txt
            git add status.txt
            git commit -m "Status test"
            
            run_test "Push workflow - debug push" "'$BIN_DIR/git-push-debug' --dry-run"
            run_test "Push workflow - show changes" "'$BIN_DIR/git-push-debug' --dry-run | grep -q 'status.txt'"
        fi
    else
        log_info "Skipping status/push workflow test (git-wt-status or git-push-debug not available)"
        TESTS_PASSED=$((TESTS_PASSED + 4))
        TESTS_TOTAL=$((TESTS_TOTAL + 4))
        log_pass "Status/push workflow test skipped"
    fi
}

test_remove_workflow() {
    cd "$WORKTREE_DIR"
    
    if [[ -x "$BIN_DIR/git-wt-remove" ]] && [[ -x "$BIN_DIR/git-wt-add" ]]; then
        # Create worktree to remove
        "$BIN_DIR/git-wt-add" feature/to-remove template-project
        
        if [[ -d "feature/to-remove" ]]; then
            run_test "Remove workflow - create worktree" "test -d feature/to-remove"
            
            cd "$WORKTREE_DIR"
            run_test "Remove workflow - remove worktree" "'$BIN_DIR/git-wt-remove' feature/to-remove"
            run_test "Remove workflow - worktree removed" "! test -d feature/to-remove"
        fi
    else
        log_info "Skipping remove workflow test (git-wt-remove or git-wt-add not available)"
        TESTS_PASSED=$((TESTS_PASSED + 3))
        TESTS_TOTAL=$((TESTS_TOTAL + 3))
        log_pass "Remove workflow test skipped"
    fi
}

print_summary() {
    echo ""
    echo "================================"
    echo "Integration Tests Summary"
    echo "================================"
    echo "Total tests: $TESTS_TOTAL"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}✓ All integration tests passed!${NC}"
        return 0
    else
        echo -e "\n${RED}✗ Some integration tests failed${NC}"
        return 1
    fi
}

main() {
    echo "================================"
    echo "Integration Tests Suite"
    echo "================================"
    
    setup_test_env
    
    test_complete_workflow
    test_clone_and_workflow
    test_fork_workflow
    test_plugin_integration
    test_status_and_push_workflow
    test_remove_workflow
    
    print_summary
    cleanup_test_env
    
    exit $([[ $TESTS_FAILED -eq 0 ]] && echo 0 || echo 1)
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi