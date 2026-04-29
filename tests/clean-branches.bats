#!/usr/bin/env bats
# SUR-1876: lock down bash/clean-branches — single-loop driver over
# `git for-each-ref` must (a) flag local branches without an upstream,
# (b) flag local branches whose upstream has been pruned, and (c) NEVER
# delete the current branch, even in dry-run output.

setup() {
  load 'helpers.bash'
  helpers::isolate_home
  helpers::set_git_identity
  CLEAN="$REPO_ROOT/bash/clean-branches"

  # Bare "origin" repo to give branches an upstream.
  ORIGIN_DIR=$(mktemp -d)
  git -C "$ORIGIN_DIR" init --bare -q -b main

  LOCAL_DIR=$(mktemp -d)
  git -C "$LOCAL_DIR" init -q -b main
  git -C "$LOCAL_DIR" remote add origin "$ORIGIN_DIR"
  git -C "$LOCAL_DIR" commit --allow-empty -m "init" -q
  git -C "$LOCAL_DIR" push -q -u origin main

  # feature/gone: pushed, then pruned on the remote so [gone] surfaces.
  git -C "$LOCAL_DIR" checkout -q -b feature/gone
  git -C "$LOCAL_DIR" commit --allow-empty -m "fg" -q
  git -C "$LOCAL_DIR" push -q -u origin feature/gone
  git -C "$ORIGIN_DIR" branch -D feature/gone -q 2>/dev/null ||
    git -C "$ORIGIN_DIR" update-ref -d refs/heads/feature/gone

  # feature/no-upstream: created locally, never pushed.
  git -C "$LOCAL_DIR" checkout -q main
  git -C "$LOCAL_DIR" branch feature/no-upstream

  # feature/keep: current branch (also no upstream, but we must not delete it).
  git -C "$LOCAL_DIR" checkout -q -b feature/keep

  # build/1.0: pushed to origin so -T can delete it from both sides.
  git -C "$LOCAL_DIR" tag build/1.0
  git -C "$LOCAL_DIR" push -q origin build/1.0

  # v0.1.0: local-only tag that -T must leave untouched.
  git -C "$LOCAL_DIR" tag v0.1.0

  export ORIGIN_DIR LOCAL_DIR CLEAN
}

teardown() {
  rm -rf "$ORIGIN_DIR" "$LOCAL_DIR"
}

@test "dry-run flags feature/gone and feature/no-upstream, never the current branch" {
  # -v -v raises LOG_LEVEL to INFO so the would-delete log lines reach stderr.
  run "$CLEAN" -d "$LOCAL_DIR" -n -v -v
  [ "$status" -eq 0 ]
  [[ "$output" == *"would delete branch feature/gone (remote gone)"* ]]
  [[ "$output" == *"would delete branch feature/no-upstream (no remote)"* ]]
  # The current branch (feature/keep) must never appear in any "would delete"
  # or "Deleting" line.
  if echo "$output" | grep -E "(would delete branch|Deleting branch) feature/keep"; then
    return 1
  fi
}

@test "non-dry-run actually deletes the gone and no-upstream branches but keeps current" {
  run "$CLEAN" -d "$LOCAL_DIR" -v -v
  [ "$status" -eq 0 ]
  branches=$(git -C "$LOCAL_DIR" branch --format='%(refname:short)' | sort | tr '\n' ' ')
  # feature/keep is the current branch and main is preserved (it has a live
  # upstream). feature/gone and feature/no-upstream must be gone.
  [[ "$branches" == *"feature/keep"* ]]
  [[ "$branches" == *"main"* ]]
  [[ "$branches" != *"feature/gone"* ]]
  [[ "$branches" != *"feature/no-upstream"* ]]
}

@test "-T flag deletes build/* tags and preserves non-build tags" {
  run "$CLEAN" -d "$LOCAL_DIR" -T -v -v
  [ "$status" -eq 0 ]
  build_tags=$(git -C "$LOCAL_DIR" tag -l 'build/*')
  [ -z "$build_tags" ]
  v_tags=$(git -C "$LOCAL_DIR" tag -l 'v0.1.0')
  [ "$v_tags" = "v0.1.0" ]
}
