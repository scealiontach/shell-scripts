#!/usr/bin/env bats
# SUR-1936: brace depth in check-no-bare-ret must not reset function scope on
# inner `}` lines inside nested `{ ... }` groups.

setup() {
  load 'helpers.bash'
  helpers::isolate_home
  HOOK="$REPO_ROOT/tests/check-no-bare-ret.sh"
  FIXTURES="$REPO_ROOT/tests/fixtures/check-no-bare-ret"
  export HOOK FIXTURES
}

@test "nested brace group: bare capture after inner } is reported (SUR-1936)" {
  run bash "$HOOK" "$FIXTURES/nested-brace-bare-capture.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"bare capture"* ]]
  [[ "$output" == *"ret=\$?"* ]] || [[ "$output" == *'ret=$?'* ]]
}

@test "nested brace group: local ret before capture passes (SUR-1936)" {
  run bash "$HOOK" "$FIXTURES/nested-brace-local-capture.sh"
  [ "$status" -eq 0 ]
}

@test "trivial function with bare exit-code capture fails (regression)" {
  run bash "$HOOK" "$FIXTURES/trivial-bare-capture.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"bare capture"* ]]
}

@test "function ends correctly after nested groups (SUR-1936)" {
  run bash "$HOOK" "$FIXTURES/function-end-after-nested.sh"
  [ "$status" -eq 0 ]
}

@test "'#' inside parameter expansion does not drift function scope" {
  run bash "$HOOK" "$FIXTURES/param-expansion-hash.sh"
  [ "$status" -eq 0 ]
}

@test "live bash/*.sh tree is still clean under the hook" {
  run bash "$HOOK" "$REPO_ROOT"/bash/*.sh
  [ "$status" -eq 0 ]
}
