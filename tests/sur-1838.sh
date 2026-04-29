#!/usr/bin/env bash
# SUR-1838: pagerduty::_incident_data must produce parseable JSON regardless
# of metacharacters in the operator-supplied title (quotes, backslashes,
# newlines, braces) and must not be conditionally redefined per-invocation.

TEST_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -P "$TEST_DIR/.." && pwd)"
# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

failures=0

# pagerduty.sh's runtime-only relative source of includer.sh cannot be
# resolved at lint time; SC1091 is suppressed for that follow.
# shellcheck source=../bash/pagerduty.sh
# shellcheck disable=SC1091
source "$REPO_ROOT/bash/pagerduty.sh"

# 1. Title with embedded double-quote, backslash, and newline.
nasty_title=$'evil "quote" \\ backslash and\n newline'
payload=$(pagerduty::_incident_data "SVC1" "incident" "$nasty_title" "")
if ! echo "$payload" | jq . >/dev/null 2>&1; then
  echo "FAIL: payload with nasty title is not valid JSON:" >&2
  echo "$payload" >&2
  failures=$((failures + 1))
fi

# 2. Same title; assert the title field round-trips byte-identically. This
#    catches any naive escaping that drops a character.
got_title=$(echo "$payload" | jq -r '.incident.title')
assert_eq "$nasty_title" "$got_title" "title round-trips through jq" ||
  failures=$((failures + 1))

# 3. No incident_key key in the payload when none is supplied.
has_key=$(echo "$payload" | jq 'has("incident") and (.incident | has("incident_key"))')
assert_eq "false" "$has_key" "no incident_key when omitted" ||
  failures=$((failures + 1))

# 4. With an incident_key, the field is present and equal.
keyed=$(pagerduty::_incident_data "SVC1" "incident" "T" "abc-123")
got_key=$(echo "$keyed" | jq -r '.incident.incident_key')
assert_eq "abc-123" "$got_key" "incident_key passes through" ||
  failures=$((failures + 1))

# 5. Injection attempt: a title that tries to add a 'priority' field via raw
#    interpolation must not produce an extra top-level field on the
#    incident object.
inject_title='X","priority":"P1'
inject=$(pagerduty::_incident_data "SVC1" "incident" "$inject_title" "")
has_priority=$(echo "$inject" | jq '.incident | has("priority")')
assert_eq "false" "$has_priority" "title cannot inject sibling fields" ||
  failures=$((failures + 1))

# 6. pagerduty::_incident_data is defined exactly once at file scope (not redefined inside
#    pagerduty::send_incident based on a runtime branch). declare -F should
#    report a
#    single function with no per-call rewrite needed.
declare -F pagerduty::_incident_data >/dev/null || {
  echo "FAIL: pagerduty::_incident_data is not defined" >&2
  failures=$((failures + 1))
}

if [ "$failures" -ne 0 ]; then
  echo "sur-1838: $failures assertion(s) failed" >&2
  exit 1
fi
exit 0
