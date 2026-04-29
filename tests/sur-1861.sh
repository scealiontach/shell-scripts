#!/usr/bin/env bash
# SUR-1861: bash/on-change::wait_for_change must not clobber the caller's
# $COMMAND. The pre-fix code did `read -r -t "$wait_time" COMMAND`, which
# torched any $COMMAND already set in the calling shell on the first poll
# cycle (and $COMMAND is the conventional positional/option name used by
# sibling scripts like kind-test-environment and minikube-test-environment).
#
# Strategy: extract the function definition from bash/on-change via sed,
# source it in the current shell with COMMAND pre-set, drive one
# poll-and-exit cycle by feeding X<Enter> on the function's stdin (the
# documented "force re-run now" trigger), and assert $COMMAND is unchanged
# after the function returns. Process substitution keeps the read in the
# current shell so the leak — if any — is observable.

TEST_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -P "$TEST_DIR/.." && pwd)"
# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

failures=0

tmp_root=$(mktemp -d)
trap 'rm -rf "$tmp_root"' EXIT

mkdir -p "$tmp_root/watch" "$tmp_root/work"

# Extract just `wait_for_change` from bash/on-change without invoking the
# script's options::parse / main "$@" tail.
fn_src="$tmp_root/wait_for_change.sh"
sed -n '/^function wait_for_change()/,/^}/p' "$REPO_ROOT/bash/on-change" >"$fn_src"

if ! grep -q "wait_for_change" "$fn_src"; then
  echo "FAIL: failed to extract wait_for_change from bash/on-change" >&2
  exit 1
fi

# Stub the helpers wait_for_change calls so we don't pull in the full
# logging stack. shellcheck cannot see that the extracted function
# below references these, so silence SC2329.
# shellcheck disable=SC2329
log::trace() { :; }
# shellcheck disable=SC2329
error::exit() {
  echo "error::exit: $*" >&2
  return 1
}

WatchDir="$tmp_root/watch"
WorkingDir="$tmp_root/work"
export WatchDir WorkingDir

# shellcheck source=/dev/null
source "$fn_src"

# Pre-set $COMMAND in the caller, then drive one poll cycle.
# Process substitution feeds the X<Enter> trigger to the function's read
# WITHOUT spawning a pipe-induced subshell — so any leak in the read
# target would be observable in this scope.
COMMAND=preset
wait_for_change 1 < <(printf 'X\n') >/dev/null 2>&1
assert_eq "preset" "$COMMAND" \
  "wait_for_change must not clobber caller \$COMMAND" || failures=$((failures + 1))

# A second exercise: $COMMAND unset in the caller must remain unset
# (i.e. the function-local must not bleed out as a freshly-created
# global).
unset COMMAND
wait_for_change 1 < <(printf 'X\n') >/dev/null 2>&1
if declare -p COMMAND >/dev/null 2>&1; then
  echo "FAIL: \$COMMAND leaked into caller scope (was unset before call)" >&2
  failures=$((failures + 1))
fi

if [ "$failures" -ne 0 ]; then
  echo "sur-1861: $failures assertion(s) failed" >&2
  exit 1
fi
exit 0
