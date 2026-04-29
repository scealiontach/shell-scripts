#!/usr/bin/env bats
# SUR-1840: lock down the namespaced public surface of pagerduty.sh and the
# parens-only deprecated shims that delegate via `annotations::deprecated`.

setup() {
  load 'helpers.bash'
  helpers::isolate_home
}

@test "pagerduty.sh sources cleanly under @include" {
  run bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include pagerduty
    declare -F pagerduty::send_incident pagerduty::send_event \
      pagerduty::_curl pagerduty::_jq pagerduty::_incident_data
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"pagerduty::send_incident"* ]]
  [[ "$output" == *"pagerduty::send_event"* ]]
  [[ "$output" == *"pagerduty::_curl"* ]]
  [[ "$output" == *"pagerduty::_jq"* ]]
  [[ "$output" == *"pagerduty::_incident_data"* ]]
}

@test "send_incident shim delegates to pagerduty::send_incident via deprecated" {
  # The shim must still resolve and route through annotations::deprecated.
  # Stub pagerduty::send_incident to capture the call and short-circuit
  # the real curl, then invoke the bare shim.
  run bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include pagerduty
    pagerduty::send_incident() { echo \"called: \$*\"; }
    LOG_DISABLE_DEBUG=true
    send_incident SVC1 incident T from token
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"called: SVC1 incident T from token"* ]]
}

@test "send_event shim delegates to pagerduty::send_event via deprecated" {
  # send_event's real body fails loudly; the shim must reach it.
  run bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include pagerduty
    LOG_DISABLE_DEBUG=true
    send_event token SVC1 title
  "
  [ "$status" -ne 0 ]
  [[ "$output" == *"pagerduty::send_event not implemented"* ]]
}

@test "pagerduty-alert -i event produces user-facing not-supported error (SUR-1865)" {
  run bash "$REPO_ROOT/bash/pagerduty-alert" -a fake-token -s fake-svc -i event
  [ "$status" -ne 0 ]
  [[ "$output" == *"not supported"* ]] || [[ "$output" == *"Unknown"* ]]
}

@test "pagerduty-alert -h does not advertise 'event' as supported (SUR-1865)" {
  run bash "$REPO_ROOT/bash/pagerduty-alert" -h
  [[ "$output" != *"incident or event"* ]]
}

@test "pagerduty::_incident_data emits parseable JSON with the supplied fields" {
  # Smoke-check the namespaced private helper directly (the listed rename
  # of `incident_data`).
  run bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include pagerduty
    pagerduty::_incident_data svc1 incident hello-title key-1
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"hello-title"* ]]
  [[ "$output" == *"svc1"* ]]
  [[ "$output" == *"key-1"* ]]
}
