#!/usr/bin/env bats
# SUR-1881: error.sh — error::exit exits 1 with message on stderr.

setup() {
  load 'helpers.bash'
  helpers::isolate_home
}

@test "error::exit exits 1 with message" {
  run bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include error
    error::exit 'fail msg'
  "
  [ "$status" -eq 1 ]
  [[ "$output" == *"fail msg"* ]]
}

@test "error::exit exits 1 with multi-word message" {
  run bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include error
    error::exit 'something went wrong: code 42'
  "
  [ "$status" -eq 1 ]
  [[ "$output" == *"something went wrong: code 42"* ]]
}
