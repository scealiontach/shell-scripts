#!/usr/bin/env bats
# SUR-1882: changelog emits section headers for tagged commit history;
# with -l, includes commit URLs when origin is a GitHub remote.

setup() {
  load 'helpers.bash'
  helpers::isolate_home
  helpers::set_git_identity
  CHANGELOG="$REPO_ROOT/bash/changelog"
  FIXTURE_DIR=$(mktemp -d)
  helpers::make_fixture_repo "$FIXTURE_DIR" --tagged
  # Add an untagged HEAD commit so git::tagsinhistory does not confuse the
  # HEAD decoration with a tag and emits clean v0.1.0/v0.2.0/v0.3.0 names.
  (
    cd "$FIXTURE_DIR" || exit 1
    echo "post" >>README
    git add README
    git -c commit.gpgsign=false commit -q -m "feat: post-tag change"
  )
  export FIXTURE_DIR CHANGELOG
}

teardown() {
  rm -rf "$FIXTURE_DIR"
}

@test "changelog exits 0 and emits CHANGELOG header" {
  run bash -c "cd '$FIXTURE_DIR' && '$CHANGELOG'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"# CHANGELOG"* ]]
}

@test "changelog emits v0.3.0 and v0.2.0 section headers" {
  run bash -c "cd '$FIXTURE_DIR' && '$CHANGELOG'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"## v0.3.0"* ]]
  [[ "$output" == *"## v0.2.0"* ]]
}

@test "changelog -l includes GitHub commit URLs when origin is a GitHub remote" {
  git -C "$FIXTURE_DIR" remote add origin "git@github.com:testorg/testrepo.git"
  run bash -c "cd '$FIXTURE_DIR' && '$CHANGELOG' -l"
  [ "$status" -eq 0 ]
  [[ "$output" == *"https://github.com/testorg/testrepo/commit"* ]]
}
