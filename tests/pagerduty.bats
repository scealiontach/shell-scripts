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

@test "pagerduty::send_incident propagates curl failure (SUR-1931)" {
  # Regression for SUR-1931: previously the function logged "Sent" and
  # returned 0 regardless of curl exit status. Stub pagerduty::_curl to
  # exit non-zero (e.g. HTTP error code surfaced via --fail-with-body)
  # and assert the failure propagates and an error is logged.
  run bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include pagerduty
    pagerduty::_curl() { return 22; }
    pagerduty::send_incident SVC1 incident T from token
  "
  [ "$status" -eq 22 ]
  [[ "$output" == *"PagerDuty incident send failed"* ]]
  [[ "$output" != *"Sent PagerDuty incident"* ]]
}

@test "pagerduty::send_incident success path returns 0 (SUR-1931)" {
  # The "Sent" log line is emitted at INFO level which is gated off by
  # default; we just assert success-rc instead of probing stderr gating.
  run bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include pagerduty
    pagerduty::_curl() { return 0; }
    pagerduty::send_incident SVC1 incident T from token
  "
  [ "$status" -eq 0 ]
  [[ "$output" != *"PagerDuty incident send failed"* ]]
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

@test "pagerduty::_incident_data omits incident_key when key is empty (SUR-2479)" {
  run bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include pagerduty
    pagerduty::_incident_data svc incident title '' | jq -e '.incident | has(\"incident_key\") | not'
  "
  [ "$status" -eq 0 ]
}

@test "pagerduty::_incident_data includes incident_key when key non-empty (SUR-2479)" {
  run bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include pagerduty
    pagerduty::_incident_data svc incident title my-key | jq -e '.incident.incident_key == \"my-key\"'
  "
  [ "$status" -eq 0 ]
}

@test "pagerduty::send_incident passes --fail-with-body to curl on HTTP failure path (SUR-2479)" {
  run bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include pagerduty
    pagerduty::_curl() {
      case \" \$* \" in
        *' --fail-with-body '*) ;;
        *) echo 'missing --fail-with-body' >&2; return 99 ;;
      esac
      return 22
    }
    pagerduty::send_incident SVC1 incident T from token ''
  "
  [ "$status" -eq 22 ]
  [[ "$output" != *"missing --fail-with-body"* ]]
  [[ "$output" == *"PagerDuty incident send failed"* ]]
}

@test "pagerduty::send_incident does not emit Token token= secret in xtrace (SUR-2339)" {
  run bash -c "
    trace=\$(mktemp)
    trap 'rm -f \"\$trace\"' EXIT
    source '$REPO_ROOT/bash/includer.sh'
    @include pagerduty
    pagerduty::_curl() { return 0; }
    exec 2>\"\$trace\"
    set -x
    pagerduty::send_incident SVC1 incident T from 'PD_TOKEN_SUR2339_XYZ' ''
    set +x
    exec 2>&1
    if grep -F 'Token token=PD_TOKEN_SUR2339_XYZ' \"\$trace\"; then
      exit 1
    fi
    exit 0
  "
  [ "$status" -eq 0 ]
}
