#!/usr/bin/env bash

source "$(cd "${BASH_SOURCE[0]%/*}/../utils" && pwd)/common_test_functions"

# Tests for commont_test_functions
test_setup_before() {
  local output
  assert_directory_exists "${REMOTE_REPO_LOC}"
  assert_directory_not_exists "temp_init"

  output=$(git -C "${REMOTE_REPO_LOC}" branch)
  assert_contains "main" "${output}"
  assert_contains "develop" "${output}"

}

test_setup() {
  assert_directory_exists "../${TEST_DIR}"
}

test_create_worktree_clone() {
  local output
  create_worktree_clone
  # assert_directory_exists "${REMOTE_REPO_LOC}"
  assert_directory_exists "../${TEST_DIR}"
  assert_directory_exists "../${TEST_DIR}/${DIRNAME}"
  assert_directory_exists "${DIRNAME}"

  output=$(git -C "${DIRNAME}" branch)
  assert_contains "main" "${output}"
}
