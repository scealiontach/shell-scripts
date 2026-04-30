#!/usr/bin/env bats
# SUR-1859: docker::cp and docker::cp_if_different must not leak the
# intermediate `$exit_code` they capture at branch points into the
# caller's scope.

setup() {
  load 'helpers.bash'
  helpers::isolate_home
}

# Drives docker::cp with stubbed pull/tag/push functions whose return
# codes are controlled by DOCKER_PULL_RC / DOCKER_TAG_RC / DOCKER_PUSH_RC.
# Echoes "exit_code=$caller_exit_code rc=$function_rc" so a single grep
# can assert both axes.
run_cp() {
  local fn=$1
  local pull_rc=$2
  local tag_rc=$3
  local push_rc=$4
  bash -c "
    LOGFILE_DISABLE=true
    LOG_DISABLE_DEBUG=true
    LOG_DISABLE_INFO=true
    source '$REPO_ROOT/bash/includer.sh'
    @include docker
    docker::pull() { return $pull_rc; }
    docker::tag()  { return $tag_rc; }
    docker::push() { return $push_rc; }
    docker::repo_tags_has() { return 1; }
    exit_code=preset
    $fn from-img to-img
    rc=\$?
    echo \"exit_code=\$exit_code rc=\$rc\"
  "
}

@test "docker::cp success leaves caller's exit_code untouched" {
  out=$(run_cp docker::cp 0 0 0)
  [[ "$out" == "exit_code=preset rc=0" ]]
}

@test "docker::cp pull failure leaves caller's exit_code untouched" {
  out=$(run_cp docker::cp 5 0 0)
  [[ "$out" == "exit_code=preset rc=1" ]]
}

@test "docker::cp tag failure leaves caller's exit_code untouched" {
  out=$(run_cp docker::cp 0 5 0)
  [[ "$out" == "exit_code=preset rc=2" ]]
}

@test "docker::cp push failure leaves caller's exit_code untouched" {
  out=$(run_cp docker::cp 0 0 5)
  [[ "$out" == "exit_code=preset rc=3" ]]
}

@test "docker::cp_if_different success leaves caller's exit_code untouched" {
  out=$(run_cp docker::cp_if_different 0 0 0)
  [[ "$out" == "exit_code=preset rc=0" ]]
}

@test "docker::cp_if_different pull failure leaves caller's exit_code untouched" {
  out=$(run_cp docker::cp_if_different 5 0 0)
  [[ "$out" == "exit_code=preset rc=1" ]]
}

@test "docker::cp_if_different tag failure leaves caller's exit_code untouched" {
  out=$(run_cp docker::cp_if_different 0 5 0)
  [[ "$out" == "exit_code=preset rc=2" ]]
}

@test "docker::cp_if_different push failure leaves caller's exit_code untouched" {
  out=$(run_cp docker::cp_if_different 0 0 5)
  [[ "$out" == "exit_code=preset rc=3" ]]
}

# SUR-1892: exercise docker::cp through docker::cmd so the fake-PATH stub
# binary in tests/stubs/docker is invoked instead of overriding shell functions.
@test "docker::cp returns 0 on full success (fake-PATH stub)" {
  run bash -c "
    export LOGFILE_DISABLE=true LOG_DISABLE_DEBUG=true LOG_DISABLE_INFO=true
    export DOCKER_PULL_RC=0 DOCKER_TAG_RC=0 DOCKER_PUSH_RC=0 DOCKER_ARGV_LOG=/dev/null
    export PATH='$REPO_ROOT/tests/stubs:$PATH'
    source '$REPO_ROOT/bash/includer.sh'
    @include docker
    docker::cp from-img to-img
  "
  [ "$status" -eq 0 ]
}

@test "docker::cp returns 1 when docker pull fails (fake-PATH stub)" {
  run bash -c "
    export LOGFILE_DISABLE=true LOG_DISABLE_DEBUG=true LOG_DISABLE_INFO=true
    export DOCKER_PULL_RC=5 DOCKER_TAG_RC=0 DOCKER_PUSH_RC=0 DOCKER_ARGV_LOG=/dev/null
    export PATH='$REPO_ROOT/tests/stubs:$PATH'
    source '$REPO_ROOT/bash/includer.sh'
    @include docker
    docker::cp from-img to-img
  "
  [ "$status" -eq 1 ]
}

@test "docker::cp returns 2 when docker tag fails (fake-PATH stub)" {
  run bash -c "
    export LOGFILE_DISABLE=true LOG_DISABLE_DEBUG=true LOG_DISABLE_INFO=true
    export DOCKER_PULL_RC=0 DOCKER_TAG_RC=5 DOCKER_PUSH_RC=0 DOCKER_ARGV_LOG=/dev/null
    export PATH='$REPO_ROOT/tests/stubs:$PATH'
    source '$REPO_ROOT/bash/includer.sh'
    @include docker
    docker::cp from-img to-img
  "
  [ "$status" -eq 2 ]
}

@test "docker::cp returns 3 when docker push fails (fake-PATH stub)" {
  run bash -c "
    export LOGFILE_DISABLE=true LOG_DISABLE_DEBUG=true LOG_DISABLE_INFO=true
    export DOCKER_PULL_RC=0 DOCKER_TAG_RC=0 DOCKER_PUSH_RC=5 DOCKER_ARGV_LOG=/dev/null
    export PATH='$REPO_ROOT/tests/stubs:$PATH'
    source '$REPO_ROOT/bash/includer.sh'
    @include docker
    docker::cp from-img to-img
  "
  [ "$status" -eq 3 ]
}

# SUR-1927: docker::_jq must surface the standard commands::use error
# when jq is missing from PATH, instead of silently emitting nothing.
# The override of `command` returns 1 only for `command -v jq` so
# commands::use's missing-binary path fires while the rest of
# includer.sh's setup keeps working.
@test "docker::_jq fails loudly when jq is not on PATH (SUR-1927)" {
  run bash -c "
    export LOGFILE_DISABLE=true
    source '$REPO_ROOT/bash/includer.sh'
    @include docker
    command() {
      if [ \"\$1\" = -v ] && [ \"\$2\" = jq ]; then return 1; fi
      builtin command \"\$@\"
    }
    docker::_jq -r '.foo' </dev/null
  "
  [ "$status" -eq 1 ]
  [[ "$output" == *"jq is either not installed or not on the PATH"* ]]
  [[ "$output" != *"-r: command not found"* ]]
}
