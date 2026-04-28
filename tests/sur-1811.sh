#!/usr/bin/env bash
# SUR-1811: log.sh FORMAT_LOG must emit real newline (not literal \n)
# and LOG() must dispatch via case statement to log::* functions.

TEST_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -P "$TEST_DIR/.." && pwd)"
# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

failures=0

# Strip ANSI color escapes for easier substring matching.
strip_ansi() {
  # Remove ESC[ ... m sequences.
  sed -e 's/\x1b\[[0-9;]*m//g'
}

# Test A: log::log INFO emits "hello" with a real newline (no literal \n).
# log::* writes to stderr via LOG_HANDLER_COLORTERM.
a_stderr=$(
  # shellcheck source=/dev/null
  source "$REPO_ROOT/bash/includer.sh"
  @include log
  log::level 2 # ensure INFO is enabled (LOG_DISABLE_INFO=false)
  log::log INFO "hello-sur-1811" 2>&1
)
a_clean=$(printf '%s' "$a_stderr" | strip_ansi)
assert_contains "$a_clean" "hello-sur-1811" "A: INFO message present" || failures=$((failures + 1))
# Must NOT contain a literal backslash-n sequence.
case "$a_clean" in
  *'\n'*)
    printf 'FAIL: A: output contains literal \\n sequence: [%s]\n' "$a_clean" >&2
    failures=$((failures + 1))
    ;;
esac

# Test B: log::log NOTAREALLEVEL "x" — dispatcher must NOT crash and must
# emit an "Unknown log level" diagnostic via log::error.
b_stderr=$(
  # shellcheck source=/dev/null
  source "$REPO_ROOT/bash/includer.sh"
  @include log
  log::log NOTAREALLEVEL "ignored-payload" 2>&1
)
b_clean=$(printf '%s' "$b_stderr" | strip_ansi)
assert_contains "$b_clean" "Unknown log level" "B: unknown level diagnostic" || failures=$((failures + 1))
assert_contains "$b_clean" "NOTAREALLEVEL" "B: unknown level echoes original" || failures=$((failures + 1))

# Test C: case-insensitive dispatch — both lowercase and uppercase route correctly.
c_stderr=$(
  # shellcheck source=/dev/null
  source "$REPO_ROOT/bash/includer.sh"
  @include log
  log::level 4 # enable everything down to TRACE
  log::log debug "lowercase-debug-msg" 2>&1
  log::log ERROR "uppercase-error-msg" 2>&1
)
c_clean=$(printf '%s' "$c_stderr" | strip_ansi)
assert_contains "$c_clean" "lowercase-debug-msg" "C: lowercase 'debug' dispatched" || failures=$((failures + 1))
assert_contains "$c_clean" "uppercase-error-msg" "C: uppercase 'ERROR' dispatched" || failures=$((failures + 1))

if [ "$failures" -ne 0 ]; then
  echo "sur-1811: $failures assertion(s) failed" >&2
  exit 1
fi
exit 0
