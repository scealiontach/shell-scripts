#!/usr/bin/env bash
# SUR-1812: dirs::noreplace must implement its docstring contract:
# - non-existent dir -> created
# - empty dir       -> success no-op
# - non-empty dir   -> non-zero exit, diagnostic to stderr

TEST_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -P "$TEST_DIR/.." && pwd)"
# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

failures=0

# Allocate a parent tmp dir; clean up unconditionally.
tmp_parent=$(mktemp -d)
trap 'rm -rf "$tmp_parent"' EXIT

# Test A: non-existent dir gets created.
a_target="$tmp_parent/new_dir"
(
  # shellcheck source=/dev/null
  source "$REPO_ROOT/bash/includer.sh"
  @include dirs
  dirs::noreplace "$a_target"
) >/dev/null 2>&1
a_rc=$?
assert_zero "$a_rc" "A: noreplace on non-existent dir should succeed" || failures=$((failures + 1))
[ -d "$a_target" ] || {
  echo "FAIL: A: directory $a_target was not created" >&2
  failures=$((failures + 1))
}

# Test B: empty existing dir -> success no-op.
b_target="$tmp_parent/empty_dir"
mkdir -p "$b_target"
(
  # shellcheck source=/dev/null
  source "$REPO_ROOT/bash/includer.sh"
  @include dirs
  dirs::noreplace "$b_target"
) >/dev/null 2>&1
b_rc=$?
assert_zero "$b_rc" "B: noreplace on empty dir should succeed" || failures=$((failures + 1))
[ -d "$b_target" ] || {
  echo "FAIL: B: directory $b_target should still exist" >&2
  failures=$((failures + 1))
}

# Test C: non-empty existing dir -> non-zero exit; stderr names the dir.
c_target="$tmp_parent/nonempty_dir"
mkdir -p "$c_target"
touch "$c_target/marker"
c_stderr=$(
  # shellcheck source=/dev/null
  source "$REPO_ROOT/bash/includer.sh"
  @include dirs
  dirs::noreplace "$c_target" 2>&1 >/dev/null
)
c_rc=$?
assert_nonzero "$c_rc" "C: noreplace on non-empty dir should exit non-zero" || failures=$((failures + 1))
assert_contains "$c_stderr" "$c_target" "C: stderr should contain the dir path" || failures=$((failures + 1))
# Marker still present (no destruction).
[ -f "$c_target/marker" ] || {
  echo "FAIL: C: marker file should be preserved (no clobber)" >&2
  failures=$((failures + 1))
}

if [ "$failures" -ne 0 ]; then
  echo "sur-1812: $failures assertion(s) failed" >&2
  exit 1
fi
exit 0
