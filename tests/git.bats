#!/usr/bin/env bats
# SUR-1850 seed: git::projecturl rewrites for github remotes; ignores others.

setup() {
  load 'helpers.bash'
  helpers::isolate_home
  helpers::set_git_identity
  REPO=$(mktemp -d)
  (cd "$REPO" && git init -q .)
}

teardown() {
  rm -rf "$REPO"
}

run_projecturl_with_remote() {
  local url=$1
  # Run the body under bash -c so shellcheck does not statically follow
  # the dynamic `source $REPO_ROOT/...` chain — which would dead-end at
  # includer.sh's BASH_SOURCE-relative `source ".../doc.sh"`.
  bash -c "
    cd '$REPO' &&
      git remote remove origin 2>/dev/null
    git remote add origin '$url'
    source '$REPO_ROOT/bash/includer.sh'
    @include git
    git::projecturl
  "
}

@test "git::projecturl strips .git on ssh github URL" {
  out=$(run_projecturl_with_remote "git@github.com:scealiontach/shell-scripts.git")
  [ "$out" = "https://github.com/scealiontach/shell-scripts/commit" ]
}

@test "git::projecturl strips .git on https github URL" {
  out=$(run_projecturl_with_remote "https://github.com/scealiontach/shell-scripts.git")
  [ "$out" = "https://github.com/scealiontach/shell-scripts/commit" ]
}

@test "git::projecturl handles github URL without .git suffix" {
  out=$(run_projecturl_with_remote "git@github.com:scealiontach/shell-scripts")
  [ "$out" = "https://github.com/scealiontach/shell-scripts/commit" ]
}

@test "git::projecturl emits nothing for non-github remotes" {
  out=$(run_projecturl_with_remote "git@gitlab.com:foo/bar.git")
  [ -z "$out" ]
}
