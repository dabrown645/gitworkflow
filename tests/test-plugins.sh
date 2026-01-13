#!/bin/bash

# Test script for Git Worktree Plugin System
# Tests plugin manager functionality and individual plugins

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test tracking
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PLUGIN_MANAGER="$PROJECT_DIR/plugins/plugin-manager.sh"
TEST_DIR="/tmp/git-worktree-plugin-tests"

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    log_info "Running: $test_name"
    
    if eval "$test_command" > /dev/null 2>&1; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "$test_name"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_error "$test_name"
        echo "  Command: $test_command"
        return 1
    fi
}

run_test_with_output() {
    local test_name="$1"
    local test_command="$2"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    log_info "Running: $test_name"
    
    if eval "$test_command"; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "$test_name"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_error "$test_name"
        echo "  Command: $test_command"
        return 1
    fi
}

setup_test_env() {
    log_info "Setting up test environment"
    
    # Clean up any existing test directory
    rm -rf "$TEST_DIR"
    mkdir -p "$TEST_DIR"
    
    # Reset plugin state
    rm -rf "$PROJECT_DIR/plugins/enabled"
    mkdir -p "$PROJECT_DIR/plugins/enabled"
    
    # Make plugin manager executable
    chmod +x "$PLUGIN_MANAGER"
    
    # Make plugins executable
    chmod +x "$PROJECT_DIR/plugins/available"/*.sh
}

create_sample_projects() {
    log_info "Creating sample projects for testing"
    
    # JavaScript project
    mkdir -p "$TEST_DIR/js-project"
    cat > "$TEST_DIR/js-project/package.json" << 'EOF'
{
  "name": "test-js-project",
  "version": "1.0.0",
  "scripts": {
    "test": "echo \"Error: no test specified\" && exit 1"
  },
  "dependencies": {
    "lodash": "^4.17.21"
  }
}
EOF
    
    # Python project (pip)
    mkdir -p "$TEST_DIR/python-project"
    cat > "$TEST_DIR/python-project/requirements.txt" << 'EOF'
requests==2.31.0
flask==3.0.0
EOF
    
    # Python project (uv)
    mkdir -p "$TEST_DIR/uv-project"
    cat > "$TEST_DIR/uv-project/pyproject.toml" << 'EOF'
[project]
name = "test-uv-project"
version = "0.1.0"
description = "Test UV project"
dependencies = [
    "requests>=2.31.0",
    "flask>=3.0.0",
]
EOF
    
    # Rust project
    mkdir -p "$TEST_DIR/rust-project"
    cat > "$TEST_DIR/rust-project/Cargo.toml" << 'EOF'
[package]
name = "test-rust-project"
version = "0.1.0"
edition = "2021"

[dependencies]
serde = "1.0"
EOF
    
    mkdir -p "$TEST_DIR/rust-project/src"
    cat > "$TEST_DIR/rust-project/src/main.rs" << 'EOF'
fn main() {
    println!("Hello, world!");
}
EOF
}

# Test functions
test_plugin_manager_exists() {
    run_test "Plugin manager exists" "test -f '$PLUGIN_MANAGER'"
}

test_plugin_manager_executable() {
    run_test "Plugin manager is executable" "test -x '$PLUGIN_MANAGER'"
}

test_help_command() {
    run_test "Help command works" "'$PLUGIN_MANAGER' help | grep -q 'Plugin Manager'"
}

test_list_available() {
    run_test_with_output "List available plugins" "'$PLUGIN_MANAGER' list-available"
}

test_list_enabled_empty() {
    run_test "List enabled (empty initially)" "! '$PLUGIN_MANAGER' list-enabled | grep -v 'Enabled plugins:' | grep -v '(none)'"
}

test_enable_plugin() {
    run_test_with_output "Enable javascript plugin" "'$PLUGIN_MANAGER' enable javascript"
    run_test "Plugin is enabled" "test -L '$PROJECT_DIR/plugins/enabled/javascript.sh'"
}

test_disable_plugin() {
    run_test_with_output "Disable javascript plugin" "'$PLUGIN_MANAGER' disable javascript"
    run_test "Plugin is disabled" "! test -L '$PROJECT_DIR/plugins/enabled/javascript.sh'"
}

test_plugin_detection() {
    # Enable all plugins for detection testing
    "$PLUGIN_MANAGER" enable javascript > /dev/null 2>&1 || true
    "$PLUGIN_MANAGER" enable python > /dev/null 2>&1 || true
    "$PLUGIN_MANAGER" enable rust > /dev/null 2>&1 || true
    
    run_test "JavaScript plugin detects JS project" "cd '$TEST_DIR/js-project' && source '$PROJECT_DIR/plugins/available/javascript.sh' && plugin_detect"
    run_test "Python plugin detects Python project" "cd '$TEST_DIR/python-project' && source '$PROJECT_DIR/plugins/available/python.sh' && plugin_detect"
    run_test "UV plugin detects UV project" "cd '$TEST_DIR/uv-project' && source '$PROJECT_DIR/plugins/available/python.sh' && plugin_detect"
    run_test "Rust plugin detects Rust project" "cd '$TEST_DIR/rust-project' && source '$PROJECT_DIR/plugins/available/rust.sh' && plugin_detect"
}

test_plugin_status() {
    cd "$TEST_DIR/js-project"
    export PLUGINS_DIR="$PROJECT_DIR/plugins"
    
    run_test "JavaScript plugin lists status" "source '$PROJECT_DIR/plugins/enabled/javascript.sh' && plugin_list_status | grep -q 'JavaScript Project'"
}

test_auto_setup() {
    # Test auto-setup on sample projects
    run_test_with_output "Auto-setup JavaScript project" "'$PLUGIN_MANAGER' auto-setup '$TEST_DIR/js-project'"
}

test_cleanup() {
    run_test_with_output "Cleanup JavaScript project" "'$PLUGIN_MANAGER' cleanup '$TEST_DIR/js-project'"
}

# Integration tests
test_full_workflow() {
    log_info "Testing full workflow"
    
    # Enable javascript plugin
    "$PLUGIN_MANAGER" enable javascript > /dev/null 2>&1
    
    # Run auto-setup
    cd "$TEST_DIR/js-project"
    if "$PLUGIN_MANAGER" auto-setup "." 2>/dev/null; then
        log_success "Full workflow completed"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_error "Full workflow failed"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
}

print_summary() {
    echo ""
    echo "================================"
    echo "Test Summary"
    echo "================================"
    echo "Total tests: $TESTS_TOTAL"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}✓ All tests passed!${NC}"
        return 0
    else
        echo -e "\n${RED}✗ Some tests failed${NC}"
        return 1
    fi
}

cleanup() {
    log_info "Cleaning up test environment"
    rm -rf "$TEST_DIR"
}

# Main test execution
main() {
    echo "================================"
    echo "Git Worktree Plugin System Tests"
    echo "================================"
    
    # Setup
    setup_test_env
    create_sample_projects
    
    # Basic tests
    test_plugin_manager_exists
    test_plugin_manager_executable
    test_help_command
    test_list_available
    test_list_enabled_empty
    
    # Plugin management tests
    test_enable_plugin
    test_disable_plugin
    
    # Plugin functionality tests
    test_plugin_detection
    test_plugin_status
    test_auto_setup
    test_cleanup
    
    # Integration tests
    test_full_workflow
    
    # Summary and cleanup
    print_summary
    cleanup
    
    exit $([[ $TESTS_FAILED -eq 0 ]] && echo 0 || echo 1)
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi