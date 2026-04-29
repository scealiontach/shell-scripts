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
  # Unset git plumbing env vars that git sets when running hooks.  Without
  # this, git -C <tmpdir> calls inside tests inherit the outer GIT_DIR and
  # operate on the project repo instead of the intended temp repo.
  unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY
}

# Deterministic git author/committer identity for tests that exercise
# git history (e.g. update-repo-tags).
helpers::set_git_identity() {
  export GIT_AUTHOR_NAME="Bats Tester"
  export GIT_AUTHOR_EMAIL="bats@example.invalid"
  export GIT_COMMITTER_NAME="Bats Tester"
  export GIT_COMMITTER_EMAIL="bats@example.invalid"
}

# helpers::make_fixture_repo <dir> [--tagged]
# Creates a minimal git repo at <dir> with one commit (or three tagged commits
# when --tagged is passed). Calls helpers::set_git_identity internally so
# callers need not do so first.
helpers::make_fixture_repo() {
  local dir=${1:?dir required}
  local tagged=${2:-}
  git init -q -b main "$dir"
  (
    cd "$dir" || exit 1
    helpers::set_git_identity
    touch README
    git add README
    git -c commit.gpgsign=false commit -q -m "feat: initial"
    if [[ "$tagged" == "--tagged" ]]; then
      git tag v0.1.0
      echo "a" >>README
      git add README
      git -c commit.gpgsign=false commit -q -m "feat: second"
      git tag v0.2.0
      echo "b" >>README
      git add README
      git -c commit.gpgsign=false commit -q -m "feat: third"
      git tag v0.3.0
    fi
  )
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
