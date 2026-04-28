#!/usr/bin/env bats
# SUR-1848 follow-up: lock down registry-cp's exit-code dispatch on top of
# docker::cp's documented 0/1/2/3 contract by routing through a recording
# docker stub on PATH.

setup() {
  load 'helpers.bash'
  helpers::isolate_home
  STUB_BIN="$REPO_ROOT/tests/stubs"
  DOCKER_ARGV_LOG=$(mktemp)
  PATH="$STUB_BIN:$PATH"
  unset _docker
  REGISTRY_CP="$REPO_ROOT/bash/registry-cp"
  ARGS=(-f srcreg -i myimg -r 1.2.3 -t dstreg)
  export STUB_BIN DOCKER_ARGV_LOG PATH REGISTRY_CP
}

teardown() {
  rm -f "$DOCKER_ARGV_LOG"
}

@test "registry-cp success path: docker pull, tag, push all called" {
  run "$REGISTRY_CP" "${ARGS[@]}"
  [ "$status" -eq 0 ]
  argv=$(cat "$DOCKER_ARGV_LOG")
  # docker::pull adds -q, so the source URL is the second arg, not the first
  [[ "$argv" == *"pull"*"srcreg/myimg:1.2.3"* ]]
  [[ "$argv" == *"tag srcreg/myimg:1.2.3 dstreg/myimg:1.2.3"* ]]
  [[ "$argv" == *"push dstreg/myimg:1.2.3"* ]]
}

@test "registry-cp pull failure: exits non-zero, message names pull and source" {
  DOCKER_PULL_RC=42 run "$REGISTRY_CP" "${ARGS[@]}"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Failed to pull srcreg/myimg:1.2.3"* ]]
  argv=$(cat "$DOCKER_ARGV_LOG")
  # tag/push must NOT have been attempted after pull failed
  [[ "$argv" != *"tag "* ]]
  [[ "$argv" != *"push "* ]]
}

@test "registry-cp tag failure: exits non-zero, message names tag and destination" {
  DOCKER_TAG_RC=42 run "$REGISTRY_CP" "${ARGS[@]}"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Failed to tag dstreg/myimg:1.2.3"* ]]
  argv=$(cat "$DOCKER_ARGV_LOG")
  [[ "$argv" == *"pull "* ]]
  # push must NOT have been attempted after tag failed
  [[ "$argv" != *"push "* ]]
}

@test "registry-cp push failure: exits non-zero, message names push and destination" {
  DOCKER_PUSH_RC=42 run "$REGISTRY_CP" "${ARGS[@]}"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Failed to push dstreg/myimg:1.2.3"* ]]
}
