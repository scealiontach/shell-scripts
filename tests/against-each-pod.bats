#!/usr/bin/env bats
# SUR-1841 follow-up: assert against-each-pod routes -n NAMESPACE through
# k8s::pod_names_for_label rather than via ad-hoc positional parsing.

setup() {
  load 'helpers.bash'
  helpers::isolate_home
  STUB_BIN="$REPO_ROOT/tests/stubs"
  KUBECTL_ARGV_LOG=$(mktemp)
  PATH="$STUB_BIN:$PATH"
  unset _kubectl
  AGAINST="$REPO_ROOT/bash/against-each-pod"
  export STUB_BIN KUBECTL_ARGV_LOG PATH AGAINST
}

teardown() {
  rm -f "$KUBECTL_ARGV_LOG"
}

@test "against-each-pod -n NAMESPACE flows through to kubectl" {
  # The stub's pod listing also drives the per-pod jq lookup, but jq
  # isn't installed in CI runners by default; redirect stderr away so
  # the test focuses on the argv contract for the listing call.
  run "$AGAINST" -n my-ns app=foo describe
  argv=$(cat "$KUBECTL_ARGV_LOG")
  [[ "$argv" == *"-l app=foo"* ]]
  [[ "$argv" == *"--field-selector=status.phase=Running"* ]]
  [[ "$argv" == *"-o name"* ]]
  [[ "$argv" == *"-n my-ns"* ]]
}

@test "against-each-pod without -n omits namespace from kubectl argv" {
  run "$AGAINST" app=foo describe
  argv=$(cat "$KUBECTL_ARGV_LOG")
  [[ "$argv" == *"-l app=foo"* ]]
  # The very first kubectl invocation is the listing call. Per-pod
  # follow-up calls (get pod -o json) carry no -n, so we only need to
  # assert the listing line itself does not include -n.
  first=$(head -n1 "$KUBECTL_ARGV_LOG")
  [[ "$first" != *" -n "* ]]
}

@test "against-each-pod default path does not invoke clear" {
  clear_dir=$(mktemp -d)
  CLEAR_INVOKED=$(mktemp)
  export CLEAR_INVOKED
  cat >"$clear_dir/clear" <<'EOS'
#!/bin/sh
echo invoked >>"$CLEAR_INVOKED"
EOS
  chmod +x "$clear_dir/clear"
  PATH="$clear_dir:$STUB_BIN:$PATH"
  run "$AGAINST" app=foo describe
  [[ ! -s "$CLEAR_INVOKED" ]]
  rm -f "$CLEAR_INVOKED"
  rm -rf "$clear_dir"
}
