#!/usr/bin/env bats

setup() {
  load 'helpers.bash'
  helpers::isolate_home
  MDDOC="$REPO_ROOT/bash/mddoc"
  FIXTURE="$REPO_ROOT/tests/fixtures/mddoc/leading_space_marker.txt"
  export MDDOC FIXTURE
}

@test "mddoc missing argument prints usage to stderr and exits non-zero" {
  run "$MDDOC"
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"mddoc: usage:"* ]]
}

@test "mddoc extracts lines with leading whitespace before ## @md" {
  run "$MDDOC" "$FIXTURE"
  [[ "$status" -eq 0 ]]
  # bats trims one trailing newline from combined stdout/stderr capture.
  [[ "$output" == $'One\nTwo' ]]
}
