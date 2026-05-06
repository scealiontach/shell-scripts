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

# SUR-1840: log::_format is the new namespaced helper. Public name shim
# FORMAT_LOG must continue to resolve and produce identical output so
# existing callers don't notice the rename.
@test "log::_format and FORMAT_LOG both produce the formatted line" {
  out=$(bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include log
    LOG_FORMAT='%LEVEL %MESSAGE'
    log::_format INFO hello-fmt
    FORMAT_LOG INFO hello-fmt
  ")
  [[ "$out" == *"INFO hello-fmt"* ]]
  # Two invocations -> two lines containing the marker.
  count=$(printf '%s\n' "$out" | grep -c 'INFO hello-fmt' || true)
  [ "$count" = "2" ]
}

# SUR-1840: log::_handler_default is a thin alias around the
# LOG_HANDLER_DEFAULT override hook. Redefining the override hook before
# invoking the namespaced alias must take effect — that is the documented
# extension point.
@test "LOG_HANDLER_DEFAULT remains overridable through log::_handler_default" {
  out=$(bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include log
    LOG_HANDLER_DEFAULT() { echo \"OVERRIDE \$*\"; }
    log::_handler_default INFO via-namespaced-alias
  ")
  [[ "$out" == "OVERRIDE INFO via-namespaced-alias" ]]
}

# SUR-1840: deprecated public log shims (TRACE, DEBUG, ...) keep routing
# through annotations::deprecated to the namespaced log::* function.
# `annotations` must be sourced for `deprecated` to resolve — log.sh
# intentionally does not include annotations to avoid a circular dep.
@test "log::error writes to LOGFILE when caller pre-sets LOGFILE_DISABLE=false (SUR-1925)" {
  sink="$BATS_TEST_TMPDIR/log-1925.log"
  rm -f "$sink"
  bash -c "
    LOGFILE='$sink'
    LOGFILE_DISABLE=false
    source '$REPO_ROOT/bash/includer.sh'
    @include log
    log::error msg-from-1925
  " 2>/dev/null
  grep -q msg-from-1925 "$sink"
}

@test "log::error skips LOGFILE under default LOGFILE_DISABLE (SUR-1925)" {
  sink="$BATS_TEST_TMPDIR/log-1925-default.log"
  rm -f "$sink"
  bash -c "
    LOGFILE='$sink'
    source '$REPO_ROOT/bash/includer.sh'
    @include log
    log::error msg-default
  " 2>/dev/null
  [ ! -e "$sink" ] || [ ! -s "$sink" ]
}

@test "TRACE/DEBUG/INFO bare names still delegate to log::*" {
  out=$(bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include log
    @include annotations
    LOG_DISABLE_DEBUG=true
    log::info() { echo \"hit-info \$*\"; }
    INFO from-shim
  " 2>&1)
  [[ "$out" == *"hit-info from-shim"* ]]
}

# SUR-2347: source-time guard must initialise each LOG_DISABLE_* flag
# independently. Pre-fix: pre-setting only one flag short-circuited the
# `if [ -z ... ] && [ -z ... ] && ...` guard, leaving the other three
# unset (empty), so `[ "$LOG_DISABLE_X" = "false" ]` evaluated false and
# silently disabled those levels.
@test "log.sh initialises every LOG_DISABLE_* flag independently when caller pre-sets one (SUR-2347)" {
  out=$(bash -c "
    LOG_DISABLE_INFO=false
    LOG_LEVEL=4
    source '$REPO_ROOT/bash/includer.sh'
    @include log
    echo \"TRACE=\$LOG_DISABLE_TRACE DEBUG=\$LOG_DISABLE_DEBUG INFO=\$LOG_DISABLE_INFO WARNING=\$LOG_DISABLE_WARNING\"
  ")
  [[ "$out" == "TRACE=false DEBUG=false INFO=false WARNING=false" ]]
}

# Caller pre-set values must survive log::level's recompute (i.e. the
# caller's explicit pre-set wins over the LOG_LEVEL default).
@test "log.sh preserves caller pre-set LOG_DISABLE_* values (SUR-2347)" {
  out=$(bash -c "
    LOG_DISABLE_INFO=true
    LOG_LEVEL=4
    source '$REPO_ROOT/bash/includer.sh'
    @include log
    echo \"INFO=\$LOG_DISABLE_INFO\"
  ")
  [[ "$out" == "INFO=true" ]]
}

# When no flag is pre-set, behaviour matches the existing baseline:
# log::level "$LOG_LEVEL" populates all four.
@test "log.sh source-time init matches log::level when nothing pre-set (SUR-2347)" {
  out=$(bash -c "
    LOG_LEVEL=2
    source '$REPO_ROOT/bash/includer.sh'
    @include log
    echo \"TRACE=\$LOG_DISABLE_TRACE DEBUG=\$LOG_DISABLE_DEBUG INFO=\$LOG_DISABLE_INFO WARNING=\$LOG_DISABLE_WARNING\"
  ")
  [[ "$out" == "TRACE=true DEBUG=true INFO=false WARNING=false" ]]
}

# SUR-2331: log::_format substitutes %MESSAGE last so a literal
# placeholder inside the user-supplied message survives without being
# re-interpreted by the subsequent %LEVEL/%PID/%DATE substitutions.
@test "log::_format does not re-interpret %LEVEL inside the message (SUR-2331)" {
  out=$(bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include log
    LOG_FORMAT='%LEVEL %MESSAGE'
    log::_format INFO 'literal %LEVEL'
  ")
  # The level is INFO and the message contains the literal token %LEVEL.
  # Pre-fix the output was 'INFO INFO literal INFO' — message substituted
  # first, then the %LEVEL inside the message got re-substituted.
  [[ "$out" == "INFO literal %LEVEL" ]]
}

@test "log::_format does not re-interpret %PID inside the message (SUR-2331)" {
  out=$(bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include log
    LOG_FORMAT='%LEVEL %MESSAGE'
    log::_format INFO 'pid=%PID'
  ")
  [[ "$out" == "INFO pid=%PID" ]]
}

@test "log::_format does not re-interpret %DATE inside the message (SUR-2331)" {
  out=$(bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include log
    LOG_FORMAT='%LEVEL %MESSAGE'
    log::_format INFO 'date=%DATE'
  ")
  [[ "$out" == "INFO date=%DATE" ]]
}

# SUR-2475: log::level_decrease floor guard

@test "log::level_decrease from non-zero decrements LOG_LEVEL (SUR-2475)" {
  out=$(bash -c "
    LOG_LEVEL=2
    source '$REPO_ROOT/bash/includer.sh'
    @include log
    log::level_decrease
    echo \$LOG_LEVEL
  ")
  [ "$out" = "1" ]
}

@test "log::level_decrease at LOG_LEVEL=0 leaves level unchanged (SUR-2475)" {
  out=$(bash -c "
    LOG_LEVEL=0
    source '$REPO_ROOT/bash/includer.sh'
    @include log
    log::level_decrease 2>/dev/null
    echo \$LOG_LEVEL
  ")
  [ "$out" = "0" ]
}
