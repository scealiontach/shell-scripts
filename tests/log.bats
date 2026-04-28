#!/usr/bin/env bats
# SUR-1850 seed: log::level cumulative gating per documented table.

setup() {
  load 'helpers.bash'
  helpers::isolate_home
}

# Probe LOG_DISABLE_* flags after log::level "$N". Returns
# space-separated "TRACE=$x DEBUG=$x INFO=$x WARNING=$x".
probe_level() {
  local n=$1
  bash -c "
    LOGFILE_DISABLE=true
    source '$REPO_ROOT/bash/includer.sh'
    @include log
    log::level $n
    echo \"TRACE=\$LOG_DISABLE_TRACE DEBUG=\$LOG_DISABLE_DEBUG INFO=\$LOG_DISABLE_INFO WARNING=\$LOG_DISABLE_WARNING\"
  "
}

@test "log::level 0 disables WARNING, INFO, DEBUG, TRACE" {
  out=$(probe_level 0)
  [[ "$out" == "TRACE=true DEBUG=true INFO=true WARNING=true" ]]
}

@test "log::level 1 enables WARNING only above the always-on tier" {
  out=$(probe_level 1)
  [[ "$out" == "TRACE=true DEBUG=true INFO=true WARNING=false" ]]
}

@test "log::level 2 also enables INFO" {
  out=$(probe_level 2)
  [[ "$out" == "TRACE=true DEBUG=true INFO=false WARNING=false" ]]
}

@test "log::level 3 also enables DEBUG" {
  out=$(probe_level 3)
  [[ "$out" == "TRACE=true DEBUG=false INFO=false WARNING=false" ]]
}

@test "log::level 4 enables everything including TRACE" {
  out=$(probe_level 4)
  [[ "$out" == "TRACE=false DEBUG=false INFO=false WARNING=false" ]]
}
