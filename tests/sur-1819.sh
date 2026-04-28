#!/usr/bin/env bash
# SUR-1819: options.sh must not leak loop / helper variables into the caller's
# scope. Variables to check: opt, items, count, mandatory, args.

TEST_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -P "$TEST_DIR/.." && pwd)"
# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

failures=0

# Test A: sourcing options.sh (which calls options::add at top level) must not
# leak `opt` into the caller scope.
(
  unset opt items count mandatory args
  # shellcheck source=/dev/null
  source "$REPO_ROOT/bash/includer.sh"
  @include options
  # After source: assert variables remain unset.
  assert_no_var opt "A: 'opt' should not leak from options::add" || exit 1
  assert_no_var items "A: 'items' should not leak from options::syntax" || exit 1
  assert_no_var count "A: 'count' should not leak from options::doc" || exit 1
  assert_no_var mandatory "A: 'mandatory' should not leak from options::doc" || exit 1
  assert_no_var args "A: 'args' should not leak from options::doc" || exit 1
)
a_rc=$?
assert_zero "$a_rc" "A: no variable leaks after source" || failures=$((failures + 1))

# Test B: explicitly invoke options::syntax and options::doc, then check no leaks.
(
  unset opt items count mandatory args
  # shellcheck source=/dev/null
  source "$REPO_ROOT/bash/includer.sh"
  @include options
  options::syntax somecmd >/dev/null
  options::doc somecmd >/dev/null
  assert_no_var items "B: 'items' should not leak from options::syntax" || exit 1
  assert_no_var count "B: 'count' should not leak from options::doc" || exit 1
  assert_no_var mandatory "B: 'mandatory' should not leak from options::doc" || exit 1
  assert_no_var args "B: 'args' should not leak from options::doc" || exit 1
  assert_no_var opt "B: 'opt' should not leak after explicit calls" || exit 1
)
b_rc=$?
assert_zero "$b_rc" "B: no variable leaks after explicit invocation" || failures=$((failures + 1))

# Test C: smoke an existing command-script's -h help path to confirm
# options.sh end-to-end still prints help and exits zero.
NO_SYNTAX_EXIT=1 bash "$REPO_ROOT/bash/clean-branches" -h >/tmp/sur1819-help.$$ 2>&1
c_rc=$?
# clean-branches -h triggers options::syntax_exit which `exit 1`s.
# Either exit code is fine as long as the SYNTAX heading was printed.
help_out=$(cat /tmp/sur1819-help.$$)
rm -f /tmp/sur1819-help.$$
assert_contains "$help_out" "SYNTAX" "C: -h should print SYNTAX section" || failures=$((failures + 1))
# Mark c_rc as observed (lint silence).
: "$c_rc"

if [ "$failures" -ne 0 ]; then
  echo "sur-1819: $failures assertion(s) failed" >&2
  exit 1
fi
exit 0
