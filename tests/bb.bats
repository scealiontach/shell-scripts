#!/usr/bin/env bats
# SUR-1927: bb must route every jq invocation through a commands::use
# -backed shim so a missing jq binary fails loudly with the standard
# "not on the PATH" error rather than silently emitting empty output
# downstream.

setup() {
  load 'helpers.bash'
  helpers::isolate_home
  TARGET="$REPO_ROOT/bash/bb"
  export TARGET
}

@test "bb defines a ::jq shim" {
  run grep -E '^function ::jq\(\)' "$TARGET"
  [ "$status" -eq 0 ]
}

@test "bb has no bare jq invocation" {
  run grep -nE '^[^#]*(^|[^:_a-z])jq([[:space:]]|$)' "$TARGET"
  [ "$status" -ne 0 ]
}

@test "bb ::jq shim fails loudly when jq is missing from PATH (SUR-1927)" {
  run bash -c "
    export LOGFILE_DISABLE=true
    source '$REPO_ROOT/bash/includer.sh'
    @include commands
    @include log
    eval \"\$(awk '/^function ::jq\\(\\)/,/^}\$/' '$TARGET')\"
    command() {
      if [ \"\$1\" = -v ] && [ \"\$2\" = jq ]; then return 1; fi
      builtin command \"\$@\"
    }
    ::jq -r '.foo' </dev/null
  "
  [ "$status" -eq 1 ]
  [[ "$output" == *"jq is either not installed or not on the PATH"* ]]
  [[ "$output" != *"-r: command not found"* ]]
}
