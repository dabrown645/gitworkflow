#!/bin/bash

# Master test runner for all git-wt* and git-push* scripts
# Runs individual test suites and provides overall summary

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BIN_DIR="$PROJECT_DIR/bin"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test suite paths
GITWT_TESTS="$SCRIPT_DIR/git-wt"
GITPUSH_TESTS="$SCRIPT_DIR/git-push"
UNIT_TESTS="$SCRIPT_DIR/unit"
INTEGRATION_TESTS="$SCRIPT_DIR/integration"
PLUGIN_TESTS="$PROJECT_DIR/tests/test-plugins.sh"

# Results tracking
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0
TOTAL_TESTS=0
TOTAL_PASSED=0
TOTAL_FAILED=0

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_suite() { echo -e "${YELLOW}[SUITE]${NC} $1"; }

# Run a test suite and capture results
run_test_suite() {
    local suite_name="$1"
    local test_script="$2"
    
    log_suite "Running $suite_name test suite..."
    echo "----------------------------------------"
    
    if [[ -x "$test_script" ]]; then
        # Run test and capture output
        local output
        local exit_code
        
        if output=$("$test_script" 2>&1); then
            exit_code=0
        else
            exit_code=$?
        fi
        
        # Strip ANSI color codes from output for parsing
        local clean_output
        clean_output=$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g')
        
        # Extract test counts from output
        local suite_total=0
        local suite_passed=0
        local suite_failed=0
        
        if echo "$clean_output" | grep -q "Total tests:"; then
            suite_total=$(echo "$clean_output" | grep "Total tests:" | sed 's/.*Total tests: \([0-9]*\).*/\1/')
            suite_passed=$(echo "$clean_output" | grep "Passed:" | sed 's/.*Passed: \([0-9]*\).*/\1/')
            suite_failed=$(echo "$clean_output" | grep "Failed:" | sed 's/.*Failed: \([0-9]*\).*/\1/')
        else
            # Fallback: count from PASS/FAIL lines if summary not found
            suite_total=$(echo "$clean_output" | grep -c "\[PASS\]\|\[FAIL\]" || true)
            suite_passed=$(echo "$clean_output" | grep -c "\[PASS\]" || true)
            suite_failed=$(echo "$clean_output" | grep -c "\[FAIL\]" || true)
        fi
        
        # Update global counters
        TOTAL_SUITES=$((TOTAL_SUITES + 1))
        TOTAL_TESTS=$((TOTAL_TESTS + suite_total))
        TOTAL_PASSED=$((TOTAL_PASSED + suite_passed))
        TOTAL_FAILED=$((TOTAL_FAILED + suite_failed))
        
        # Determine success based on test results, not exit code
        if [[ $suite_failed -eq 0 && $suite_total -gt 0 ]]; then
            PASSED_SUITES=$((PASSED_SUITES + 1))
            log_success "$suite_name: ✓ $suite_passed/$suite_total tests passed"
        else
            FAILED_SUITES=$((FAILED_SUITES + 1))
            log_error "$suite_name: ✗ $suite_failed/$suite_total tests failed"
            # Don't show details unless verbose mode is enabled
        fi
        
        # Show full output if verbose mode is enabled
        if [[ "$VERBOSE" == "true" ]]; then
            echo ""
            echo "----------------------------------------"
            echo "Full test output for $suite_name:"
            echo "----------------------------------------"
            echo "$output"
            echo "----------------------------------------"
        fi
    else
        log_error "$suite_name: Test script not found or not executable: $test_script"
        FAILED_SUITES=$((FAILED_SUITES + 1))
        TOTAL_SUITES=$((TOTAL_SUITES + 1))
    fi
    
    echo ""
}

# Show usage information
show_usage() {
    cat << 'EOF'
Master Test Runner for Git Workflow Tools

Usage: run-all-tests.sh [options] [test-suites...]

Options:
  --help, -h         Show this help
  --list, -l         List available test suites
  --clean, -c        Clean test artifacts before running
  --verbose, -v       Show detailed output from all tests

Test Suites:
  git-wt-add          Test git worktree addition functionality
  git-wt-remove       Test git worktree removal functionality  
  git-wt-status       Test git worktree status display
  git-wt-clone        Test git repository cloning with worktree setup
  git-wt-clone-fork  Test git repository fork cloning
  git-push-debug       Test git push debugging and validation
  unit                Test core functions and components
  integration         Test end-to-end workflows
  plugins             Test plugin system functionality
  all                 Run all test suites (default)

Examples:
  ./run-all-tests.sh                    # Run all tests
  ./run-all-tests.sh git-wt-add plugins  # Run specific suites
  ./run-all-tests.sh --list            # List available suites
  ./run-all-tests.sh --clean            # Clean and run all tests
  ./run-all-tests.sh --verbose          # Run all tests with detailed output

EOF
}

# List available test suites
list_test_suites() {
    echo "Available Test Suites:"
    echo "  git-wt-add          git worktree addition"
    echo "  git-wt-remove       git worktree removal"
    echo "  git-wt-status       git worktree status"
    echo "  git-wt-clone        repository cloning"
    echo "  git-wt-clone-fork  repository fork cloning"
    echo "  git-push-debug       git push debugging"
    echo "  unit                core functions"
    echo "  integration         end-to-end workflows"
    echo "  plugins             plugin system"
    echo "  all                 all suites (default)"
}

# Clean test artifacts
clean_test_artifacts() {
    log_info "Cleaning test artifacts..."
    
    # Remove common test directories
    local artifacts=(
        "/tmp/git-wt-*"
        "/tmp/integration-test-*"
        "/tmp/test-*"
        "/tmp/plugin-test-*"
    )
    
    for artifact in "${artifacts[@]}"; do
        if ls -d $artifact 2>/dev/null; then
            rm -rf $artifact
            log_info "Removed: $artifact"
        fi
    done
    
    # Remove git operation leftovers
    find /tmp -name ".git" -type d -exec rm -rf {} + 2>/dev/null || true
    
    log_info "Test artifacts cleaned"
}

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    # Check for required scripts
    local required_scripts=(
        "git-wt-add"
        "git-wt-remove" 
        "git-wt-status"
        "git-wt-clone"
        "git-wt-clone-fork"
        "git-push-debug"
        "plugin-manager"
    )
    
    for script in "${required_scripts[@]}"; do
        local script_path="$BIN_DIR/$script"
        if [[ ! -f "$script_path" ]]; then
            missing_deps+=("$script (not found)")
        elif [[ ! -x "$script_path" ]]; then
            missing_deps+=("$script (not executable)")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing dependencies:"
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep"
        done
        return 1
    fi
    
    return 0
}

# Parse command line arguments
parse_args() {
    SUITES_TO_RUN=()
    CLEAN_ARTIFACTS=false
    VERBOSE=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_usage
                exit 0
                ;;
            --list|-l)
                list_test_suites
                exit 0
                ;;
            --clean|-c)
                CLEAN_ARTIFACTS=true
                shift
                ;;
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            git-wt-add|git-wt-remove|git-wt-status|git-wt-clone|git-wt-clone-fork|git-push-debug|unit|integration|plugins|all)
                SUITES_TO_RUN+=("$1")
                shift
                ;;
            *)
                echo "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Default to all suites if none specified
    if [[ ${#SUITES_TO_RUN[@]} -eq 0 ]]; then
        SUITES_TO_RUN=("all")
    fi
}

# Main execution
main() {
    echo "================================"
    echo "Git Workflow Tools - Master Test Runner"
    echo "================================"
    
    parse_args "$@"
    
    # Check dependencies first
    if ! check_dependencies; then
        exit 1
    fi
    
    # Clean artifacts if requested
    if [[ "$CLEAN_ARTIFACTS" ]]; then
        clean_test_artifacts
    fi
    
    # Determine which suites to run
    for suite in "${SUITES_TO_RUN[@]}"; do
        case $suite in
            git-wt-add)
                run_test_suite "git-wt-add" "$GITWT_TESTS/test-git-wt-add.sh"
                ;;
            git-wt-remove)
                run_test_suite "git-wt-remove" "$GITWT_TESTS/test-git-wt-remove.sh"
                ;;
            git-wt-status)
                run_test_suite "git-wt-status" "$GITWT_TESTS/test-git-wt-status.sh"
                ;;
            git-wt-clone)
                run_test_suite "git-wt-clone" "$GITWT_TESTS/test-git-wt-clone.sh"
                ;;
            git-wt-clone-fork)
                run_test_suite "git-wt-clone-fork" "$GITWT_TESTS/test-git-wt-clone-fork.sh"
                ;;
            git-push-debug)
                run_test_suite "git-push-debug" "$GITPUSH_TESTS/test-git-push-debug.sh"
                ;;
            unit)
                run_test_suite "Unit Tests" "$UNIT_TESTS/test-core-functions.sh"
                ;;
            integration)
                run_test_suite "Integration Tests" "$INTEGRATION_TESTS/test-workflow.sh"
                ;;
            plugins)
                run_test_suite "Plugin Tests" "$PLUGIN_TESTS"
                ;;
            all)
                run_test_suite "git-wt-add" "$GITWT_TESTS/test-git-wt-add.sh"
                run_test_suite "git-wt-remove" "$GITWT_TESTS/test-git-wt-remove.sh"
                run_test_suite "git-wt-status" "$GITWT_TESTS/test-git-wt-status.sh"
                run_test_suite "git-wt-clone" "$GITWT_TESTS/test-git-wt-clone.sh"
                run_test_suite "git-wt-clone-fork" "$GITWT_TESTS/test-git-wt-clone-fork.sh"
                run_test_suite "git-push-debug" "$GITPUSH_TESTS/test-git-push-debug.sh"
                run_test_suite "Unit Tests" "$UNIT_TESTS/test-core-functions.sh"
                run_test_suite "Integration Tests" "$INTEGRATION_TESTS/test-workflow.sh"
                run_test_suite "Plugin Tests" "$PLUGIN_TESTS"
                ;;
        esac
    done
    
    # Print final summary
    echo "================================"
    echo "Final Test Summary"
    echo "================================"
    echo "Test Suites: $TOTAL_SUITES"
    echo -e "Passed Suites: ${GREEN}$PASSED_SUITES${NC}"
    echo -e "Failed Suites: ${RED}$FAILED_SUITES${NC}"
    echo ""
    echo "Total Tests: $TOTAL_TESTS"
    echo -e "Total Passed: ${GREEN}$TOTAL_PASSED${NC}"
    echo -e "Total Failed: ${RED}$TOTAL_FAILED${NC}"
    
    if [[ $TOTAL_FAILED -eq 0 ]]; then
        echo ""
        echo -e "${GREEN}🎉 ALL TESTS PASSED! 🎉${NC}"
        echo -e "${GREEN}All git workflow tools are functioning correctly!${NC}"
        exit 0
    else
        echo ""
        echo -e "${RED}❌ SOME TESTS FAILED ❌${NC}"
        echo -e "${RED}Please check the failed test suites above.${NC}"
        exit 1
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi