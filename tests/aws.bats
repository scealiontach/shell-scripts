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

@test "aws::is_scan_complete returns 0 when scan status is COMPLETE" {
  run bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include aws
    aws::scan_status() { echo 'COMPLETE'; }
    aws::is_scan_complete myrepo mytag
  "
  [ "$status" -eq 0 ]
}

@test "aws::is_scan_complete returns 1 when scan status is IN_PROGRESS" {
  run bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include aws
    aws::scan_status() { echo 'IN_PROGRESS'; }
    aws::is_scan_complete myrepo mytag
  "
  [ "$status" -ne 0 ]
}

@test "aws::is_scan_complete returns 1 for any non-COMPLETE status" {
  run bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include aws
    aws::scan_status() { echo 'FAILED'; }
    aws::is_scan_complete myrepo mytag
  "
  [ "$status" -ne 0 ]
}

@test "aws::wait_for_scan_complete returns non-zero after bounded attempts when stuck (SUR-2340)" {
  run bash -c "
    export LOG_DISABLE_TRACE=true
    source '$REPO_ROOT/bash/includer.sh'
    @include aws
    aws::scan_status() { echo 'IN_PROGRESS'; }
    sleep() { :; }
    aws::wait_for_scan_complete myrepo mytag 0 5
  "
  [ "$status" -ne 0 ]
}

@test "aws::wait_for_scan_complete returns non-zero promptly on FAILED status (SUR-2340)" {
  run bash -c "
    export LOG_DISABLE_TRACE=true
    source '$REPO_ROOT/bash/includer.sh'
    @include aws
    aws::scan_status() { echo 'FAILED'; }
    sleep() { :; }
    aws::wait_for_scan_complete myrepo mytag 0 99
  "
  [ "$status" -ne 0 ]
}
