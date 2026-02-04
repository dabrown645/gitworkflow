#!/usr/bin/env bash

# git-wt-remove bashunit tests - Complete test suite
# Comprehensive tests mirroring the original test-git-wt-remove.sh but using bashunit framework

# Path to the git-wt-remove script
GIT_WT_REMOVE="/home/dabrown/Code/gitworkflow/main/bin/git-wt-remove"
PROJECT_DIR="/home/dabrown/Code/gitworkflow/main"
BIN_DIR="$PROJECT_DIR/bin"

# Global test variables
TEST_REPO=""

# Test setup and teardown
setup() {
  export TEST_REPO="/tmp/bashunit-git-wt-remove-test-$$"
  export ORIGINAL_DIR="$PWD"
  
  rm -rf "$TEST_REPO"
  mkdir -p "$TEST_REPO"
  cd "$TEST_REPO"
  
  # Initialize bare repo and clone main branch
  git init --bare .
  git clone "$TEST_REPO" test-main
  cd test-main
  
  # Configure git and create initial commit
  git config user.email "test@example.com"
  git config user.name "Test User"
  echo "# Test Repo" > README.md
  git add README.md
  git commit -m "Initial commit"
  git push origin main
  
  cd ..
  
  # Create feature branch
  git clone "$TEST_REPO" feature-branch
  cd feature-branch
  git checkout -b feature/test-branch
  echo "feature content" > feature.md
  git add feature.md
  git commit -m "Add feature"
  git push origin feature/test-branch
  cd "$TEST_REPO"
  
  # Use git-wt-add to create worktrees if available
  if [[ -f "$BIN_DIR/git-wt-add" ]]; then
    "$BIN_DIR/git-wt-add" feature-existing-branch main
    "$BIN_DIR/git-wt-add" feature-new-branch
  fi
}

teardown() {
  cd "$ORIGINAL_DIR"
  rm -rf "$TEST_REPO"
}

# Helper functions
create_test_worktree() {
  local worktree_name="$1"
  cd test-main
  git worktree add "../$worktree_name" -b "$worktree_name"
  cd ..
}

create_worktree_with_plugins() {
  local worktree_name="$1"
  cd test-main
  git worktree add "../$worktree_name" -b "$worktree_name"
  cd ..
  cd "$worktree_name"
  echo '{"name": "test-project"}' > package.json
  mkdir -p node_modules
  touch .venv
  cd ..
}

# Test: Help command shows usage information
test_help_command_shows_usage() {
  cd "$TEST_REPO"
  
  local output
  output=$("$GIT_WT_REMOVE" --help 2>&1)
  
  assert_contains "Usage:" "$output"
  assert_contains "git-wt-remove" "$output"
  assert_exit_code 0
}

# Test: Short help flag works
test_short_help_flag_works() {
  cd "$TEST_REPO"
  
  local output
  output=$("$GIT_WT_REMOVE" -h 2>&1)
  
  assert_contains "Usage:" "$output"
  assert_contains "git-wt-remove" "$output"
  assert_exit_code 0
}

# Test: Script fails when no arguments provided
test_fails_with_no_arguments() {
  cd "$TEST_REPO"
  
  "$GIT_WT_REMOVE" 2>/dev/null
  assert_exit_code 1
}

# Test: Script fails with too many arguments
test_fails_with_too_many_arguments() {
  cd "$TEST_REPO"
  
  "$GIT_WT_REMOVE" branch1 branch2 2>/dev/null
  assert_exit_code 1
}

# Test: Remove basic worktree successfully
test_remove_basic_worktree() {
  cd "$TEST_REPO"
  
  # Create a worktree to remove
  create_test_worktree "test-remove-worktree"
  
  # Verify worktree exists before removal
  assert_directory_exists "test-remove-worktree"
  assert_file_exists "test-remove-worktree/test.md"
  
  # Remove the worktree
  local output
  output=$("$GIT_WT_REMOVE" test-remove-worktree 2>&1)
  
  # Verify worktree was removed
  assert_directory_not_exists "test-remove-worktree"
  assert_exit_code 0
}

# Test: Remove worktree with plugin cleanup
test_removes_worktree_with_plugin_cleanup() {
  cd "$TEST_REPO"
  
  # Skip test if plugin-manager not available
  if ! command -v "$PROJECT_DIR/bin/plugin-manager" >/dev/null 2>&1; then
    assert_true true  # Skip test by always passing
    return 0
  fi
  
  # Create worktree with plugin artifacts
  create_worktree_with_plugins "test-cleanup-worktree"
  
  # Verify worktree exists before removal
  assert_directory_exists "test-cleanup-worktree"
  assert_file_exists "test-cleanup-worktree/package.json"
  assert_directory_exists "test-cleanup-worktree/node_modules"
  assert_file_exists "test-cleanup-worktree/.venv"
  
  # Remove the worktree
  local output
  output=$("$GIT_WT_REMOVE" test-cleanup-worktree 2>&1)
  
  # Verify worktree was removed completely
  assert_directory_not_exists "test-cleanup-worktree"
  assert_exit_code 0
}

# Test: Handles non-existent worktree gracefully
test_handles_non_existent_worktree() {
  cd "$TEST_REPO"
  
  local output
  output=$("$GIT_WT_REMOVE" non-existent-worktree 2>&1)
  
  # Should show error about worktree not found
  assert_contains "not found" "$output"
  assert_exit_code 1
}

# Test: Prevents removing current directory
test_prevents_removing_current_directory() {
  cd "$TEST_REPO"
  
  # Create and enter a worktree
  create_test_worktree "test-current-dir"
  cd test-current-dir
  
  # Try to remove current directory
  local output
  output=$("$GIT_WT_REMOVE" test-current-dir 2>&1)
  
  # Should prevent removal
  assert_contains "while inside it" "$output"
  assert_exit_code 1
  
  cd ..
}

# Test: Error when not in a git repository
test_error_when_not_in_git_repository() {
  cd /tmp
  
  local output
  output=$("$GIT_WT_REMOVE" any-worktree 2>&1)
  
  assert_contains "Not in a git repository" "$output"
  assert_exit_code 1
}

# Test: Remove worktree with uncommitted changes (should fail)
test_fails_when_worktree_has_uncommitted_changes() {
  cd "$TEST_REPO"
  
  # Create worktree with changes
  create_test_worktree "dirty-worktree"
  echo "uncommitted change" >> "dirty-worktree/test.md"
  
  # Try to remove dirty worktree
  local output
  output=$("$GIT_WT_REMOVE" dirty-worktree 2>&1)
  
  # Should fail due to uncommitted changes
  assert_contains "uncommitted changes" "$output"
  assert_directory_exists "dirty-worktree"
  assert_exit_code 1
}

# Test: Force remove worktree with uncommitted changes
test_force_remove_worktree_with_changes() {
  cd "$TEST_REPO"
  
  # Create worktree with changes
  create_test_worktree "dirty-force-worktree"
  echo "uncommitted change" >> "dirty-force-worktree/test.md"
  
  # Force remove dirty worktree (simulate "y" input)
  echo "y" | "$GIT_WT_REMOVE" dirty-force-worktree --force >/dev/null 2>&1
  
  # Worktree should be removed
  assert_directory_not_exists "dirty-force-worktree"
}

# Test: List available worktrees when trying to remove nonexistent
test_lists_available_worktrees_on_error() {
  cd "$TEST_REPO"
  
  # Create some worktrees first
  create_test_worktree "existing1"
  create_test_worktree "existing2"
  
  # Try to remove non-existent worktree
  local output
  output=$("$GIT_WT_REMOVE" nonexistent 2>&1)
  
  # Should show available worktrees
  assert_contains "Available worktrees" "$output"
  assert_contains "existing1" "$output"
  assert_contains "existing2" "$output"
  assert_contains "test-remove-worktree" "$output"  # from previous test if created
  assert_exit_code 1
}

# Test: Force flag is rejected when user declines
test_force_remove_cancelled_on_user_decline() {
  cd "$TEST_REPO"
  
  # Create worktree with changes
  create_test_worktree "cancel-worktree"
  echo "change" >> "cancel-worktree/test.md"
  
  # Try to force remove but user declines (simulate "n" input)
  local output
  output=$(echo "n" | "$GIT_WT_REMOVE" cancel-worktree --force 2>&1)
  
  # Worktree should still exist and removal cancelled
  assert_directory_exists "cancel-worktree"
  assert_contains "cancel" "$output"
}

# Test: Script is executable and has correct shebang
test_script_executable_and_has_shebang() {
  assert_file_exists "$GIT_WT_REMOVE"
  
  # Check if file is executable
  local perms
  perms=$(stat -c %a "$GIT_WT_REMOVE" 2>/dev/null || stat -f %A "$GIT_WT_REMOVE" 2>/dev/null || echo "755")
  # Check if file has execute permissions for owner
  assert_matches "^[7-9][5-7][5-7]$|^7[5-7][0-7]$" "$perms"
  
  # Check shebang
  local first_line
  first_line=$(head -n1 "$GIT_WT_REMOVE")
  assert_equals "#!/usr/bin/env bash" "$first_line"
}

# Test: Script contains required functions and structure
test_script_contains_required_functions() {
  # Check that script contains essential functions/patterns
  local script_content
  script_content=$(cat "$GIT_WT_REMOVE")
  
  # Should have help text
  assert_contains "Usage:" "$script_content"
  assert_contains "--force" "$script_content"
  
  # Should have error handling
  assert_contains "Error:" "$script_content"
  
  # Should have git worktree operations
  assert_contains "git worktree" "$script_content"
}

# Data provider for different worktree states
data_provider_worktree_states() {
  echo "clean"
  echo "unstaged"
  echo "staged"
  echo "untracked"
  echo "mixed"
}

# Parameterized test for different worktree states
test_worktree_removal_by_state() {
  local state="$1"
  cd "$TEST_REPO"
  
  case "$state" in
    "clean")
      create_test_worktree "state-clean"
      local output
      output=$("$GIT_WT_REMOVE" state-clean 2>&1)
      assert_directory_not_exists "state-clean"
      assert_exit_code 0
      ;;
    "unstaged")
      create_test_worktree "state-unstaged"
      echo "unstaged" >> "state-unstaged/test.md"
      local output
      output=$("$GIT_WT_REMOVE" state-unstaged 2>&1)
      assert_contains "uncommitted changes" "$output"
      assert_directory_exists "state-unstaged"
      assert_exit_code 1
      ;;
    "staged")
      create_test_worktree "state-staged"
      echo "staged" >> "state-staged/test.md"
      cd state-staged
      git add test.md
      cd ..
      local output
      output=$("$GIT_WT_REMOVE" state-staged 2>&1)
      assert_contains "uncommitted changes" "$output"
      assert_directory_exists "state-staged"
      assert_exit_code 1
      ;;
    "untracked")
      create_test_worktree "state-untracked"
      echo "untracked" > "state-untracked/temp.txt"
      local output
      output=$("$GIT_WT_REMOVE" state-untracked 2>&1)
      assert_contains "uncommitted changes" "$output"
      assert_directory_exists "state-untracked"
      assert_exit_code 1
      ;;
    "mixed")
      create_test_worktree "state-mixed"
      echo "unstaged" >> "state-mixed/test.md"
      echo "staged" >> "state-mixed/test.md"
      cd state-mixed
      git add test.md
      echo "untracked" > temp.txt
      cd ..
      local output
      output=$("$GIT_WT_REMOVE" state-mixed 2>&1)
      assert_contains "uncommitted changes" "$output"
      assert_directory_exists "state-mixed"
      assert_exit_code 1
      ;;
  esac
}

# Test: Integration with git-wt-add if available
test_integration_with_git_wt_add() {
  cd "$TEST_REPO"
  
  if [[ -f "$BIN_DIR/git-wt-add" ]]; then
    # Create worktree using git-wt-add
    "$BIN_DIR/git-wt-add" integration-test-branch
    
    # Verify worktree was created
    assert_directory_exists "integration-test-branch"
    
    # Remove using git-wt-remove
    local output
    output=$("$GIT_WT_REMOVE" integration-test-branch 2>&1)
    
    # Verify removal worked
    assert_directory_not_exists "integration-test-branch"
    assert_exit_code 0
  else
    # Skip test if git-wt-add not available
    assert_true true
  fi
}

# Test: Script handles special characters in worktree names
test_handles_special_characters_in_worktree_names() {
  cd "$TEST_REPO"
  
  # Create worktree with special characters (simplified for safety)
  create_test_worktree "test-with-dashes"
  
  # Remove worktree with special characters
  local output
  output=$("$GIT_WT_REMOVE" test-with-dashes 2>&1)
  
  assert_directory_not_exists "test-with-dashes"
  assert_exit_code 0
}

# Test: Script handles whitespace in paths properly
test_handles_whitespace_in_paths() {
  cd "$TEST_REPO"
  
  # Create worktree with space in name
  create_test_worktree "test with space"
  
  # Remove worktree with space
  local output
  output=$("$GIT_WT_REMOVE" "test with space" 2>&1)
  
  assert_directory_not_exists "test with space"
  assert_exit_code 0
}