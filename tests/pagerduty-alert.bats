#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# SUR-2836: direct coverage of bash/pagerduty-alert (the executable
# wrapper). The supporting library bash/pagerduty.sh has its own spec
# (tests/pagerduty.bats); this file targets the entry script's own
# logic: option validation, ALERT_TYPE dispatch, default ALERT_FROM
# and ALERT_TITLE fallbacks, the non-`incident` error::exit path, and
# propagation of a send failure.
#
# Stub seam: we suppress the real @include of pagerduty.sh by setting
# its dedup guard variable up-front, then define `pagerduty::send_incident`
# in-process to capture argv. exec.sh's `exec::hide` is reused as-is —
# it just runs its args, so the stubbed send still records the call.

setup() {
  load 'helpers.bash'
  helpers::isolate_home
  ALERT="$REPO_ROOT/bash/pagerduty-alert"
  export LOGFILE_DISABLE=true LOG_DISABLE_DEBUG=true LOG_DISABLE_INFO=true
}

# Run pagerduty-alert with a pre-installed `pagerduty::send_incident`
# stub that records argv to $log and returns $rc. Stubs are stamped in
# before sourcing pagerduty-alert by reserving pagerduty.sh's @include
# dedup guard.
_run_alert() {
  local log=${1:?}
  local rc=${2:?}
  shift 2
  bash -c '
    set +e
    log="$1"
    rc="$2"
    shift 2
    # Reserve pagerduty.sh dedup guard so @include skips it.
    cksum=$(cksum "'"$REPO_ROOT"'/bash/pagerduty.sh" | awk "{print \$1}")
    declare -g "include_${cksum}=include_${cksum}"
    # Stub records argv and returns the requested exit code so we can
    # exercise both the success path and the error::exit failure path.
    pagerduty::send_incident() {
      printf "%s\n" "$*" >>"$log"
      return "$rc"
    }
    export -f pagerduty::send_incident
    source "'"$ALERT"'" "$@"
  ' _runner "$log" "$rc" "$@"
}

@test "pagerduty-alert exits non-zero when -a is missing (SUR-2836 case 1)" {
  run bash "$ALERT" -s svc -i incident
  [ "$status" -ne 0 ]
  [[ "$output" == *"Missing required option: -a"* ]] || [[ "$output" == *"-a"* ]]
}

@test "pagerduty-alert exits non-zero when -s is missing (SUR-2836 case 1)" {
  run bash "$ALERT" -a token -i incident
  [ "$status" -ne 0 ]
  [[ "$output" == *"Missing required option: -s"* ]] || [[ "$output" == *"-s"* ]]
}

@test "pagerduty-alert exits non-zero when -i is missing (SUR-2836 case 1)" {
  run bash "$ALERT" -a token -s svc
  [ "$status" -ne 0 ]
  [[ "$output" == *"Missing required option: -i"* ]] || [[ "$output" == *"-i"* ]]
}

@test "pagerduty-alert dispatches incident with the documented argv order (SUR-2836 case 2)" {
  log=$(mktemp)
  _run_alert "$log" 0 \
    -a my-token -s SVC1 -i incident -t "My Title" -f "me@example.invalid" -k key-1
  [ "$(wc -l <"$log")" -eq 1 ]
  read -r call <"$log"
  # Order per pagerduty-alert: SERVICE_ID ALERT_TYPE ALERT_TITLE ALERT_FROM ALERT_TOKEN INCIDENT_KEY
  [[ "$call" == "SVC1 incident My Title me@example.invalid my-token key-1" ]]
  rm -f "$log"
}

@test "pagerduty-alert supplies default ALERT_TITLE and ALERT_FROM (SUR-2836 case 3)" {
  log=$(mktemp)
  _run_alert "$log" 0 -a token -s SVC1 -i incident -k key-2
  read -r call <"$log"
  [[ "$call" == *"Test Alert"* ]]
  [[ "$call" == *"no-reply@blockchaintp.com"* ]]
  rm -f "$log"
}

@test "pagerduty-alert rejects unknown -i alert types via error::exit (SUR-2836 case 4)" {
  run bash "$ALERT" -a token -s SVC1 -i event
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown -i alert type"* ]] || [[ "$output" == *"only 'incident' is supported"* ]]
}

@test "pagerduty-alert propagates send_incident failure (SUR-2836 case 5)" {
  log=$(mktemp)
  # rc=22 mirrors the curl --fail HTTP-error code used elsewhere in
  # the pagerduty specs; any non-zero return must surface as the
  # `Failed to send incident` error::exit path.
  run _run_alert "$log" 22 -a token -s SVC1 -i incident
  [ "$status" -ne 0 ]
  [[ "$output" == *"Failed to send incident"* ]]
  rm -f "$log"
}
