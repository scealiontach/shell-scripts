#!/usr/bin/env bash
# Shared bats helpers. Each .bats spec sources this in `setup_file` or
# `setup` to get a deterministic environment and a small set of helpers.

# Resolve repo root once. tests/helpers.bash lives at REPO_ROOT/tests/.
TEST_HELPERS_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export TEST_HELPERS_DIR
REPO_ROOT="$(cd -P "$TEST_HELPERS_DIR/.." && pwd)"
export REPO_ROOT

# A deterministic HOME prevents tests from writing into the real user
# home (log files, gitconfig overrides, etc.). Also unset the env vars
# that would otherwise let a developer machine's per-user XDG/git config
# leak in past the new HOME — important for local dev runs since CI
# already starts with a clean environment.
helpers::isolate_home() {
  local h
  h=$(mktemp -d)
  HOME=$h
  export HOME
  unset XDG_CONFIG_HOME GIT_CONFIG_GLOBAL GIT_CONFIG_SYSTEM
}

# Deterministic git author/committer identity for tests that exercise
# git history (e.g. update-repo-tags).
helpers::set_git_identity() {
  export GIT_AUTHOR_NAME="Bats Tester"
  export GIT_AUTHOR_EMAIL="bats@example.invalid"
  export GIT_COMMITTER_NAME="Bats Tester"
  export GIT_COMMITTER_EMAIL="bats@example.invalid"
}

# Source a library by its @include name. Forces a fresh include in the
# current shell so the cksum-keyed dedup guard cannot suppress it.
helpers::source_lib() {
  local name=${1:?lib name required}
  # shellcheck disable=SC1091
  source "$REPO_ROOT/bash/includer.sh"
  # shellcheck disable=SC1090
  @include "$name"
}
