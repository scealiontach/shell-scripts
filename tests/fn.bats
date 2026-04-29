#!/usr/bin/env bats
# SUR-1881: fn.sh — fn::if_exists and fn::wrapped dispatch contracts.

setup() {
  load 'helpers.bash'
  helpers::isolate_home
}

@test "fn::if_exists calls the function when it exists" {
  run bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include fn
    my_fn() { echo called; }
    fn::if_exists my_fn
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"called"* ]]
}

@test "fn::if_exists silently returns 0 when the function does not exist" {
  run bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include fn
    fn::if_exists nonexistent_fn_xyz_123
  "
  [ "$status" -eq 0 ]
}

@test "fn::if_exists passes additional args to the function" {
  run bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include fn
    my_fn() { echo \"called:\$*\"; }
    fn::if_exists my_fn arg1 arg2
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"called:arg1 arg2"* ]]
}

@test "fn::wrapped calls wrapper with remaining args when wrapper exists" {
  run bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include fn
    my_wrapper() { echo \"wrapper:\$*\"; }
    fn::wrapped my_wrapper arg1 arg2
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"wrapper:arg1 arg2"* ]]
}

@test "fn::wrapped falls through to direct call when wrapper is absent" {
  run bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include fn
    actual_cmd() { echo \"direct:\$*\"; }
    fn::wrapped nonexistent_wrapper_xyz actual_cmd hello
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"direct:hello"* ]]
}
