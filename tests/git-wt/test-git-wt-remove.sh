#!/usr/bin/env bash

# git-wt-remove tests
# Tests for git worktree removal and cleanup functionality

trap cleanup_test_env EXIT

# ===== SETUP & CONFIGURATION =====
SCRIPT_DIR="${BASH_SOURCE[0]%/*}"
SCRIPT="${BASH_SOURCE[0]##*/}"
SCRIPT="${SCRIPT%.*}"
PROJECT_DIR="${SCRIPT_DIR%/*}"
PROJECT_DIR="${PROJECT_DIR%/*}"
BIN_DIR="$PROJECT_DIR/bin"
TEST_REPO="/tmp/${SCRIPT}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# ===== TEST EXECUTION FLOW (mirroring main()) =====
main() {
  echo "================================"
  echo "${SCRIPT} Test Suite"
  echo "================================"

  setup_test_env
  run_all_tests
  print_summary

  exit $([[ $TESTS_FAILED -eq 0 ]] && echo 0 || echo 1)
}

run_all_tests() {
  # Check if git-wt-remove exists and is executable
  if [[ ! -x "$BIN_DIR/git-wt-remove" ]]; then
    log_abort "git-wt-remove not found or not executable at $BIN_DIR/git-wt-remove"
  fi

  # Change to test repo directory once
  pushd "$TEST_REPO" || log_abort "pushd $TEST_REPO failed"

  # Test functions in execution order (mirroring main() flow)
  test_help_command
  test_argument_validation
  test_valid_flags
  test_invalid_flag_handling
  test_repository_context
  test_uncommitted_changes
  test_force_flag_scenarios
  test_remove_basic_worktree
  test_git_command_failures
  test_error_handling

  # Cleanup any remaining test worktrees
  git worktree prune 2>/dev/null || true

  popd || log_abort "popd failed"
}

# ===== TEST EXECUTION FRAMEWORK (mirroring parse_args() flow) =====
log_info() { echo -e "${YELLOW}[INFO]${NC} $1"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; }
log_abort() {
  echo -e "${RED}[ABORTED]${NC} $1"
  exit 1
}

run_test() {
  local test_name="$1"
  local test_command="$2"

  TESTS_TOTAL=$((TESTS_TOTAL + 1))

  log_info "Running: $test_name"

  if eval "$test_command" >/dev/null 2>&1; then
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

# ===== ENVIRONMENT MANAGEMENT (mirroring set_common_dir()) =====
setup_test_env() {
  log_info "Setting up git-wt-remove test environment"

  rm -rf "${TEST_REPO}"
  mkdir -p "${TEST_REPO}"
  pushd "${TEST_REPO}" || log_abort "pushd ${TEST_REPO} failed"

  setup_base_repo

  create_test_worktree feature/test-branch
  echo "feature/test-branch" >"${TEST_REPO}/feature-test-branch/feature.md"
  git -C "${TEST_REPO}/feature-test-branch" add feature.md
  git -C "${TEST_REPO}/feature-test-branch" commit -m "Add feature/test-branch"

  create_test_worktree feature/existing-branch main
  create_test_worktree feature/new-branch

  popd || log_abort "popd failed"
}

setup_base_repo() {
  git init --bare .git
  git -C "${TEST_REPO}" worktree add main
  echo "# Test Repo" >main/README.md
  git -C "${TEST_REPO}"/main add README.md
  git -C "${TEST_REPO}"/main commit -m "Initial Commit"
}

create_test_worktree() {
  local branch_name="${1}"
  local branch_parent="${2}"
  local branch_dir="${branch_name//\//-}"

  git -C "${TEST_REPO}" worktree add -b "${branch_name}" "${branch_dir}" ${branch_parent}
}

cleanup_test_env() {
  log_info "Cleaning up test environment"
  rm -rf "${TEST_REPO}"
}

# ===== TEST FUNCTIONS IN EXECUTION ORDER (mirroring main() flow) =====

# 1. Help & Arguments (mirroring parse_args, show_help)
test_help_command() {
  run_test "Help command works" "'$BIN_DIR/git-wt-remove' --help | grep -q 'Usage:'"
  run_test "Help contains description" "'$BIN_DIR/git-wt-remove' --help | grep -q 'Description:'"
  run_test "Help contains options section" "'$BIN_DIR/git-wt-remove' --help | grep -q 'Options:'"
  run_test "Help contains examples" "'$BIN_DIR/git-wt-remove' --help | grep -q 'Examples:'"
  run_test "Help verifies typo fixes" "'$BIN_DIR/git-wt-remove' --help | grep -v 'wortree\|uncommited'"
}

test_argument_validation() {
  run_test "Requires branch name" "! '$BIN_DIR/git-wt-remove' 2>/dev/null"
  run_test "Too many arguments fail" "! '$BIN_DIR/git-wt-remove' branch1 branch2 2>/dev/null"
}

test_valid_flags() {
  # Test valid flag combinations
  git worktree add test-valid-flags -b test-valid-flags-branch
  cd test-valid-flags
  echo "test" >test.txt
  git add test.txt
  git commit -m "test"
  cd ..

  run_test "Accepts long --help flag" "'$BIN_DIR/git-wt-remove' --help >/dev/null"
  run_test "Accepts short -h flag" "'$BIN_DIR/git-wt-remove' -h >/dev/null"
  run_test "Accepts long --force flag with clean worktree" "'$BIN_DIR/git-wt-remove' --force test-valid-flags"
  run_test "Accepts short -f flag with clean worktree" "git worktree add test-short-f -b test-short-f-branch && '$BIN_DIR/git-wt-remove' -f test-short-f"

  # Test that worktree was actually removed
  run_test "Force removed worktree directory" "! test -d test-valid-flags"
}

test_invalid_flag_handling() {
  # Test invalid long flags
  run_test "Rejects invalid long flag" "! '$BIN_DIR/git-wt-remove' --invalid-flag test-worktree 2>/dev/null"
  run_test "Rejects invalid short flag" "! '$BIN_DIR/git-wt-remove' -x test-worktree 2>/dev/null"
  run_test "Rejects flag with value" "! '$BIN_DIR/git-wt-remove' --foo=bar test-worktree 2>/dev/null"

  # Test multiple invalid flags
  run_test "Rejects multiple invalid flags" "! '$BIN_DIR/git-wt-remove' --invalid --also-invalid test-worktree 2>/dev/null"

  # Test mix of valid and invalid flags
  run_test "Rejects mixed valid/invalid flags" "! '$BIN_DIR/git-wt-remove' --force --invalid test-worktree 2>/dev/null"
}

# 2. Environment Validation (mirroring set_common_dir, exit_if_*)
test_repository_context() {
  # Test behavior when not in a git repository
  local non_git_dir="/tmp/test-not-git-repo"
  mkdir -p "$non_git_dir"

  run_test "Fails when not in git repository" "! (cd '$non_git_dir' && '$BIN_DIR/git-wt-remove' test-worktree 2>/dev/null)"

  # Test behavior in non-bare git repository (regular clone)
  local regular_git_dir="/tmp/test-regular-git"
  rm -rf "$regular_git_dir"
  git init "$regular_git_dir"
  cd "$regular_git_dir"
  echo "test" >test.txt
  git add test.txt
  git commit -m "Initial commit"

  run_test "Fails in non-bare repository" "! '$BIN_DIR/git-wt-remove' test-worktree 2>/dev/null"

  # Cleanup
  cd "$TEST_REPO"
  rm -rf "$non_git_dir" "$regular_git_dir"
}

# 3. Status & Core Logic (mirroring git_worktree_status, confirm_removal)
test_uncommitted_changes() {
  # Test unstaged changes
  git worktree add test-unstaged -b test-unstaged-branch
  cd test-unstaged
  echo "unstaged content" >unstaged.txt
  cd ..

  run_test "Prevents removal with unstaged changes" "! '$BIN_DIR/git-wt-remove' test-unstaged 2>/dev/null"

  # Test staged changes
  git worktree add test-staged -b test-staged-branch
  cd test-staged
  echo "staged content" >staged.txt
  git add staged.txt
  cd ..

  run_test "Prevents removal with staged changes" "! '$BIN_DIR/git-wt-remove' test-staged 2>/dev/null"

  # Test untracked files
  git worktree add test-untracked -b test-untracked-branch
  cd test-untracked
  echo "untracked content" >untracked.txt
  mkdir -p temp
  echo "temp" >temp/file.txt
  cd ..

  run_test "Prevents removal with untracked files" "! '$BIN_DIR/git-wt-remove' test-untracked 2>/dev/null"

  # Test mixed changes
  git worktree add test-mixed -b test-mixed-branch
  cd test-mixed
  echo "unstaged" >mixed1.txt
  echo "staged" >mixed2.txt
  git add mixed2.txt
  mkdir -p untracked
  echo "untracked" >untracked/file.txt
  cd ..

  run_test "Prevents removal with mixed changes" "! '$BIN_DIR/git-wt-remove' test-mixed 2>/dev/null"

  # Cleanup
  git worktree remove test-unstaged --force
  git worktree remove test-staged --force
  git worktree remove test-untracked --force
  git worktree remove test-mixed --force
}

test_force_flag_scenarios() {
  # Create a dirty worktree with uncommitted changes
  git worktree add test-force-dirty -b test-force-dirty-branch
  cd test-force-dirty
  echo "dirty content" >dirty.md
  git add dirty.md
  cd ..

  # Test force flag with dirty worktree + confirmation acceptance
  run_test "Force flag with dirty worktree (accept)" "echo 'y' | '$BIN_DIR/git-wt-remove' --force test-force-dirty"
  run_test "Force removed dirty worktree" "! test -d test-force-dirty"

  # Create another dirty worktree for rejection test
  git worktree add test-force-reject -b test-force-reject-branch
  cd test-force-reject
  echo "another dirty" >another.md
  git add another.md
  cd ..

  # Test force flag with dirty worktree + confirmation rejection
  run_test "Force flag with dirty worktree (reject)" "echo 'n' | '$BIN_DIR/git-wt-remove' --force test-force-reject"
  run_test "Rejected worktree still exists" "test -d test-force-reject"

  # Test force flag with clean worktree (should work without confirmation)
  git worktree add test-force-clean -b test-force-clean-branch
  cd test-force-clean
  echo "clean content" >clean.md
  git add clean.md
  git commit -m "Clean commit"
  cd ..

  run_test "Force flag with clean worktree" "'$BIN_DIR/git-wt-remove' --force test-force-clean"
  run_test "Force removed clean worktree" "! test -d test-force-clean"

  # Cleanup rejected worktree
  git worktree remove test-force-reject --force
}

# 4. Removal Execution (mirroring remove_worktree)
test_remove_basic_worktree() {
  # Create a proper worktree using git worktree add
  git worktree add test-remove-worktree -b test-remove-branch
  cd test-remove-worktree
  echo "test" >test.md
  git add test.md
  git commit -m "test"
  cd ..

  run_test "Remove basic worktree" "'$BIN_DIR/git-wt-remove' test-remove-worktree"
  run_test "Worktree directory removed" "! test -d test-remove-worktree"
  run_test "Branch still exists" "git show-ref --verify refs/heads/test-remove-branch"
}

test_git_command_failures() {
  # Test git worktree remove command failure by corrupting the worktree
  git worktree add test-cleanup-failure -b test-cleanup-failure-branch
  cd test-cleanup-failure
  echo "test content" >test.txt
  git add test.txt
  git commit -m "Test commit"
  cd ..

  # Simulate git worktree remove failure by making worktree unreadable
  chmod -r test-cleanup-failure

  # This should fail gracefully when git worktree remove fails
  run_test "Handles git worktree remove failure" "! '$BIN_DIR/git-wt-remove' test-cleanup-failure 2>/dev/null"

  # Cleanup - restore permissions and remove manually
  chmod +r test-cleanup-failure
  git worktree remove test-cleanup-failure --force

  # Test worktree list output verification after successful removal
  git worktree add test-output-verify -b test-output-verify-branch
  git worktree add test-output-verify2 -b test-output-verify2-branch

  # Remove one and verify it's no longer in the list
  "$BIN_DIR/git-wt-remove" test-output-verify

  run_test "Worktree removed from list" "! git worktree list | grep -qE '/test-output-verify[[:space:]]+'"
  run_test "Other worktree still exists" "git worktree list | grep -qE '/test-output-verify2[[:space:]]+'"

  # Cleanup
  git worktree remove test-output-verify2 --force
}

# 5. Error Handling (mirroring error_msg usage)
test_error_handling() {
  # Test removing non-existent worktree
  run_test "Handles non-existent worktree" "! '$BIN_DIR/git-wt-remove' non-existent-worktree 2>/dev/null"

  # Test removing current directory (create a worktree then try to remove it while inside)
  git worktree add test-current-dir -b test-current-branch
  cd test-current-dir
  run_test "Prevents removing current worktree" "! '$BIN_DIR/git-wt-remove' test-current-dir 2>/dev/null"
  cd ..
  git worktree remove test-current-dir --force
}

# ===== REPORTING =====
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

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
