#!/usr/bin/env bats
# SUR-1881: annotations.sh — annotations::deprecated forwards args and logs.

setup() {
  load 'helpers.bash'
  helpers::isolate_home
}

@test "annotations::deprecated forwards args to new function" {
  run bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include annotations
    my_target() { echo \"called:\$*\"; }
    annotations::deprecated my_target foo bar
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"called:foo bar"* ]]
}

@test "annotations::deprecated emits debug log naming the deprecated caller" {
  run bash -c "
    LOG_LEVEL=3
    source '$REPO_ROOT/bash/includer.sh'
    @include annotations
    my_caller() {
      my_target() { :; }
      annotations::deprecated my_target
    }
    my_caller
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"my_caller"* ]]
  [[ "$output" == *"deprecated"* ]]
}

@test "deprecated shim delegates to annotations::deprecated" {
  run bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include annotations
    my_target() { echo \"via-shim:\$*\"; }
    deprecated my_target arg1
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"via-shim:arg1"* ]]
}
