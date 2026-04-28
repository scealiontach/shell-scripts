#!/usr/bin/env bash
# SUR-1813: includer.sh @include must return 1 (not exit 1) on missing file
# and write the diagnostic to stderr.

TEST_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -P "$TEST_DIR/.." && pwd)"
# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

failures=0

# Test A: missing include returns non-zero AND does not exit the runner shell.
# We source includer.sh in this same shell, then trigger a missing include.
# If the bug is present, this script would die before reaching the assertion.
# shellcheck source=/dev/null
source "$REPO_ROOT/bash/includer.sh"
@include nonexistent_lib_xyz 2>/dev/null
rc=$?
assert_nonzero "$rc" "A: missing include should return non-zero" || failures=$((failures + 1))
# If we got here, the runner shell was not killed.
assert_eq "alive" "alive" "A: runner shell still alive" || failures=$((failures + 1))

# Test B: idempotent re-include of an existing library (log).
# Source in a subshell so the include guard is fresh.
b_output=$(
  # shellcheck source=/dev/null
  source "$REPO_ROOT/bash/includer.sh"
  @include log
  @include log
  type -t log::info
)
assert_eq "function" "$b_output" "B: log::info should be a function after include" || failures=$((failures + 1))

# Confirm the cksum guard variable is present exactly once after a double include.
# shellcheck disable=SC2030,SC2031
b_guards=$(
  # shellcheck source=/dev/null
  source "$REPO_ROOT/bash/includer.sh"
  @include log
  @include log
  # Print all variables matching include_<digits>= for the log file.
  declare -p | grep -c -E '^declare -[^ ]* include_[0-9]+="include_[0-9]+"$' || true
)
# Expect at least one guard (could be more than 1 if log itself includes others).
if [ "${b_guards:-0}" -lt 1 ]; then
  echo "FAIL: B: expected at least 1 include_<cksum> guard variable, got $b_guards" >&2
  failures=$((failures + 1))
fi

# Test B2: verify the *body* of an included file runs exactly once across two
# @include calls — not just that a guard exists. Override the source builtin
# to count invocations of bash/log.sh, then double-include and assert count==1.
b2_count=$(
  # shellcheck source=/dev/null
  source "$REPO_ROOT/bash/includer.sh"
  log_source_count=0
  # shellcheck disable=SC2329,SC2317
  source() {
    case "$1" in
      */log.sh) log_source_count=$((log_source_count + 1)) ;;
    esac
    builtin source "$@"
  }
  @include log
  @include log
  echo "$log_source_count"
)
assert_eq "1" "$b2_count" "B2: log.sh body should source exactly once across two @includes" || failures=$((failures + 1))

# Test C: stderr capture of missing include contains the diagnostic.
c_stderr=$(
  # shellcheck source=/dev/null
  source "$REPO_ROOT/bash/includer.sh"
  @include nonexistent_lib_xyz 2>&1 >/dev/null
)
assert_contains "$c_stderr" "Cannot find include file" "C: stderr contains diagnostic" || failures=$((failures + 1))

if [ "$failures" -ne 0 ]; then
  echo "sur-1813: $failures assertion(s) failed" >&2
  exit 1
fi
exit 0
