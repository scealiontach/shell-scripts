#!/usr/bin/env bats
# SUR-1850 seed: git::projecturl rewrites for github remotes; ignores others.

setup() {
  load 'helpers.bash'
  helpers::isolate_home
  helpers::set_git_identity
  REPO=$(mktemp -d)
  (cd "$REPO" && git init -q .)
  # Constant rather than three repeated literals so a future repo rename
  # is a one-line edit and not three silent test failures.
  EXPECTED="https://github.com/scealiontach/shell-scripts/commit"
}

teardown() {
  rm -rf "$REPO"
}

run_git_fn_with_remote() {
  local fn=$1 url=$2
  # Run the body under bash -c so shellcheck does not statically follow
  # the dynamic `source $REPO_ROOT/...` chain — which would dead-end at
  # includer.sh's BASH_SOURCE-relative `source ".../doc.sh"`.
  bash -c "
    cd '$REPO' &&
      git remote remove origin 2>/dev/null
    git remote add origin '$url'
    source '$REPO_ROOT/bash/includer.sh'
    @include git
    $fn
  "
}

run_projecturl_with_remote() {
  run_git_fn_with_remote git::projecturl "$1"
}

@test "git::projecturl strips .git on ssh github URL" {
  out=$(run_projecturl_with_remote "git@github.com:scealiontach/shell-scripts.git")
  [ "$out" = "$EXPECTED" ]
}

@test "git::projecturl strips .git on https github URL" {
  out=$(run_projecturl_with_remote "https://github.com/scealiontach/shell-scripts.git")
  [ "$out" = "$EXPECTED" ]
}

@test "git::projecturl handles github URL without .git suffix" {
  out=$(run_projecturl_with_remote "git@github.com:scealiontach/shell-scripts")
  [ "$out" = "$EXPECTED" ]
}

@test "git::projecturl emits nothing for non-github remotes" {
  out=$(run_projecturl_with_remote "git@gitlab.com:foo/bar.git")
  [ -z "$out" ]
}

# SUR-1877: git::commit_url_base (renamed from git::projecturl) and git::project_url

@test "git::commit_url_base returns URL ending in /commit (SUR-1877)" {
  out=$(run_git_fn_with_remote git::commit_url_base "git@github.com:scealiontach/shell-scripts.git")
  [[ "$out" == */commit ]]
  [ "$out" = "$EXPECTED" ]
}

@test "git::project_url returns URL without /commit suffix (SUR-1877)" {
  out=$(run_git_fn_with_remote git::project_url "git@github.com:scealiontach/shell-scripts.git")
  [ "$out" = "https://github.com/scealiontach/shell-scripts" ]
  [[ "$out" != */commit ]]
}

@test "git::commit_url_base emits nothing for non-GitHub remotes (SUR-1877)" {
  out=$(run_git_fn_with_remote git::commit_url_base "git@gitlab.com:foo/bar.git")
  [ -z "$out" ]
}

@test "git::project_url emits nothing for non-GitHub remotes (SUR-1877)" {
  out=$(run_git_fn_with_remote git::project_url "git@gitlab.com:foo/bar.git")
  [ -z "$out" ]
}

@test "deprecated git::projecturl shim still resolves via git::commit_url_base (SUR-1877)" {
  out=$(run_projecturl_with_remote "git@github.com:scealiontach/shell-scripts.git")
  [ "$out" = "$EXPECTED" ]
}

# SUR-2454: git::tagsinhistory replaced with git for-each-ref

@test "git::tagsinhistory returns one tag per line in newest-first order (SUR-2454)" {
  TAGGED_REPO=$(mktemp -d)
  helpers::make_fixture_repo "$TAGGED_REPO" --tagged
  out=$(bash -c "
    cd '$TAGGED_REPO'
    source '$REPO_ROOT/bash/includer.sh'
    @include git
    git::tagsinhistory
  ")
  first=$(printf '%s\n' "$out" | head -1)
  last=$(printf '%s\n' "$out" | tail -1)
  [ "$first" = "v0.3.0" ]
  [ "$last" = "v0.1.0" ]
  rm -rf "$TAGGED_REPO"
}

@test "git::tagsinhistory returns empty output for repo with no tags (SUR-2454)" {
  UNTAGGED_REPO=$(mktemp -d)
  helpers::make_fixture_repo "$UNTAGGED_REPO"
  out=$(bash -c "
    cd '$UNTAGGED_REPO'
    source '$REPO_ROOT/bash/includer.sh'
    @include git
    git::tagsinhistory
  ")
  [ -z "$out" ]
  rm -rf "$UNTAGGED_REPO"
}

# SUR-2471: git::version_with_dirty_marker uses conditional --dirty semantics

@test "git::version_with_dirty_marker has no -dirty suffix on a clean tree (SUR-2471)" {
  CLEAN_REPO=$(mktemp -d)
  helpers::make_fixture_repo "$CLEAN_REPO" --tagged
  out=$(bash -c "
    cd '$CLEAN_REPO'
    source '$REPO_ROOT/bash/includer.sh'
    @include git
    git::version_with_dirty_marker
  ")
  [[ "$out" != *"-dirty" ]]
  rm -rf "$CLEAN_REPO"
}

@test "git::version_with_dirty_marker appends -dirty on a dirty tree (SUR-2471)" {
  DIRTY_REPO=$(mktemp -d)
  helpers::make_fixture_repo "$DIRTY_REPO" --tagged
  echo "dirty" >>"$DIRTY_REPO/README"
  out=$(bash -c "
    cd '$DIRTY_REPO'
    source '$REPO_ROOT/bash/includer.sh'
    @include git
    git::version_with_dirty_marker
  ")
  [[ "$out" == *"-dirty" ]]
  rm -rf "$DIRTY_REPO"
}
