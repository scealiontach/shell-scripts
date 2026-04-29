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
