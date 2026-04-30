#!/usr/bin/env bash
# SUR-1942: tests/sur-1873-makefile.sh must restore bash/log.sh mtime on exit.
# Without this, the regression test mutates a checked-in source file's mtime
# and forces spurious make rebuilds in subsequent CI steps.

TEST_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -P "$TEST_DIR/.." && pwd)"
# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

failures=0

log_sh="$REPO_ROOT/bash/log.sh"
if [ ! -f "$log_sh" ]; then
  echo "sur-1942: $log_sh missing — cannot check mtime invariant" >&2
  exit 1
fi

mtime_of() {
  stat -c '%Y' "$1" 2>/dev/null || stat -f '%m' "$1"
}

before=$(mtime_of "$log_sh")
if [ -z "$before" ]; then
  echo "sur-1942: failed to read mtime of $log_sh" >&2
  exit 1
fi

# Run the 1873 regression in a subshell. It must not leave bash/log.sh's
# mtime mutated.
bash "$TEST_DIR/sur-1873-makefile.sh" >/dev/null 2>&1
rc=$?

after=$(mtime_of "$log_sh")
assert_eq "$before" "$after" "bash/log.sh mtime preserved across sur-1873-makefile.sh" ||
  failures=$((failures + 1))

# The 1873 test itself must still pass — failing it here would mask a
# regression in the parent test.
assert_zero "$rc" "sur-1873-makefile.sh exits 0" || failures=$((failures + 1))

if [ "$failures" -ne 0 ]; then
  echo "sur-1942: $failures assertion(s) failed" >&2
  exit 1
fi
exit 0
