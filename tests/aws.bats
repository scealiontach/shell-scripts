#!/usr/bin/env bats
# SUR-1858: aws.sh must declare @include log directly so it sources
# log::* in isolation, not just through transitive options/commands
# pulls.

setup() {
  load 'helpers.bash'
  helpers::isolate_home
}

@test "aws.sh sourced in isolation resolves log::info" {
  run bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include aws
    declare -F log::info >/dev/null
  "
  [ "$status" -eq 0 ]
}

@test "aws.sh sourced in isolation resolves log::warn" {
  run bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include aws
    declare -F log::warn >/dev/null
  "
  [ "$status" -eq 0 ]
}
