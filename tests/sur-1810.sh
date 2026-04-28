#!/usr/bin/env bash
# SUR-1810: commands::use must cache the resolved path in $_<cmd>
# and skip command -v lookups on subsequent calls.

TEST_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -P "$TEST_DIR/.." && pwd)"
# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

failures=0

# Test A: commands::use bash returns a non-empty path AND populates $_bash.
a_out=$(
  # shellcheck source=/dev/null
  source "$REPO_ROOT/bash/includer.sh"
  @include commands
  commands::use bash
  # shellcheck disable=SC2154
  echo "::after::$_bash"
)
# a_out has two lines: the path returned by commands::use, then "::after::<cached>"
a_path=$(printf '%s\n' "$a_out" | sed -n '1p')
a_cached=$(printf '%s\n' "$a_out" | sed -n '2p' | sed 's/^::after:://')
if [ -z "$a_path" ]; then
  echo "FAIL: A: commands::use bash returned empty" >&2
  failures=$((failures + 1))
fi
assert_eq "$a_path" "$a_cached" "A: cached \$_bash matches returned path" || failures=$((failures + 1))

# Test B: subsequent call hits the cache (does not invoke command -v).
# Override `command` to fail; if the cache is honored, the second call still
# returns the cached value.
b_out=$(
  # shellcheck source=/dev/null
  source "$REPO_ROOT/bash/includer.sh"
  @include commands
  commands::use bash >/dev/null
  # Now break command -v so any non-cached lookup would fall through to err.
  # shellcheck disable=SC2329
  command() {
    if [ "$1" = "-v" ]; then
      return 1
    fi
    builtin command "$@"
  }
  commands::use bash
)
if [ -z "$b_out" ]; then
  echo "FAIL: B: cache miss on second commands::use bash call" >&2
  failures=$((failures + 1))
fi

# Test C: missing command triggers commands::err_not_found (non-zero exit).
# err_not_found calls `exit 1`, so we must run inside its own subshell.
(
  # shellcheck source=/dev/null
  source "$REPO_ROOT/bash/includer.sh"
  @include commands
  commands::use definitely_not_a_real_command_xyz_42 >/dev/null 2>&1
)
c_rc=$?
assert_nonzero "$c_rc" "C: missing command must exit non-zero" || failures=$((failures + 1))

if [ "$failures" -ne 0 ]; then
  echo "sur-1810: $failures assertion(s) failed" >&2
  exit 1
fi
exit 0
