#!/usr/bin/env bats
# SUR-1937: tests/check-lib-namespaces.sh used to pipe its grep output
# through `grep -v '::'`, which filtered by whole line. A single-line
# definition with a bare name and a namespaced call inside the body
# (e.g. `function init() { log::info "starting"; }`) was therefore
# silently dropped from the violation list and the hook reported zero
# issues. The hook now parses the captured function-name token and
# tests *that* token for `::` membership instead of the whole line.

setup() {
  load 'helpers.bash'
  helpers::isolate_home
  HOOK="$REPO_ROOT/tests/check-lib-namespaces.sh"
  FIXTURE="$REPO_ROOT/tests/fixtures/check-lib-namespaces/single-line-bare.sh"
  export HOOK FIXTURE
}

@test "live bash/*.sh tree is still clean under the rewritten hook" {
  run bash "$HOOK" "$REPO_ROOT"/bash/*.sh
  [ "$status" -eq 0 ]
}

@test "single-line bare function with namespaced call inside trips the hook (SUR-1937)" {
  # The hook's `case $f` guard accepts inputs only under bash/<name>.sh;
  # relocate the fixture to bash/zz_single_line.sh under a temp root
  # before invoking, and use the absolute-path form so the test does
  # not rely on cwd.
  TMPDIR_FIX=$(mktemp -d)
  mkdir -p "$TMPDIR_FIX/bash"
  cp "$FIXTURE" "$TMPDIR_FIX/bash/zz_single_line.sh"
  run bash "$HOOK" "$TMPDIR_FIX/bash/zz_single_line.sh"
  rm -rf "$TMPDIR_FIX"
  [ "$status" -eq 1 ]
  [[ "$output" == *"function init"* ]]
  [[ "$output" == *"lib-funcs-must-be-namespaced"* ]]
}

@test "namespaced single-line function does NOT trip the hook" {
  TMPDIR_FIX=$(mktemp -d)
  mkdir -p "$TMPDIR_FIX/bash"
  cat >"$TMPDIR_FIX/bash/zz_namespaced.sh" <<'EOF'
#!/usr/bin/env bash
function pkg::init() { log::info "starting"; }
EOF
  run bash "$HOOK" "$TMPDIR_FIX/bash/zz_namespaced.sh"
  rm -rf "$TMPDIR_FIX"
  [ "$status" -eq 0 ]
}
