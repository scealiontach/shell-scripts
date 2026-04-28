#!/usr/bin/env bats
# SUR-1841: lock down k8s::pod_names_for_label argv contract by routing
# through a recording kubectl stub on PATH.

setup() {
  load 'helpers.bash'
  helpers::isolate_home
  STUB_BIN="$REPO_ROOT/tests/stubs"
  KUBECTL_ARGV_LOG=$(mktemp)
  PATH="$STUB_BIN:$PATH"
  unset _kubectl
  export STUB_BIN KUBECTL_ARGV_LOG PATH
}

teardown() {
  rm -f "$KUBECTL_ARGV_LOG"
}

@test "k8s::pod_names_for_label without namespace passes -l, --field-selector, -o name" {
  run bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include k8s
    k8s::pod_names_for_label app=foo
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"example-pod-1"* ]]
  [[ "$output" == *"example-pod-2"* ]]
  argv=$(cat "$KUBECTL_ARGV_LOG")
  [[ "$argv" == *"get pods -l app=foo --field-selector=status.phase=Running -o name"* ]]
  # No -n was passed because no namespace was given.
  [[ "$argv" != *" -n "* ]]
}

@test "k8s::pod_names_for_label with namespace appends -n NAMESPACE" {
  run bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include k8s
    k8s::pod_names_for_label app=bar mynamespace
  "
  [ "$status" -eq 0 ]
  argv=$(cat "$KUBECTL_ARGV_LOG")
  [[ "$argv" == *"-l app=bar"* ]]
  [[ "$argv" == *"--field-selector=status.phase=Running"* ]]
  [[ "$argv" == *"-o name"* ]]
  [[ "$argv" == *"-n mynamespace"* ]]
}

@test "k8s::pod_names_for_label strips the pod/ prefix from -o name output" {
  run bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include k8s
    k8s::pod_names_for_label app=baz
  "
  [ "$status" -eq 0 ]
  # Output must be bare pod names (no leading pod/).
  while IFS= read -r line; do
    [[ "$line" != pod/* ]] || {
      echo "expected stripped name, got [$line]" >&2
      false
    }
  done <<<"$output"
}
