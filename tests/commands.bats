#!/usr/bin/env bats
# SUR-1850 seed: commands::use cache hit/miss + missing-binary error path.

setup() {
  load 'helpers.bash'
  helpers::isolate_home
}

@test "commands::use returns a non-empty path for an existing binary and caches it in \$_<cmd>" {
  # The cache global must be set in the same shell that calls commands::use,
  # so capture stdout via a tempfile rather than $(…) which would discard
  # the assignment back to a subshell.
  out=$(mktemp)
  run bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include commands
    commands::use bash >'$out'
    p=\$(cat '$out')
    [ -n \"\$p\" ] || { echo 'empty path' >&2; exit 1; }
    # shellcheck disable=SC2154
    [ \"\$_bash\" = \"\$p\" ] || { echo \"cache mismatch [\$_bash] vs [\$p]\" >&2; exit 1; }
  "
  rm -f "$out"
  [ "$status" -eq 0 ]
}

@test "commands::use exits non-zero when the binary is missing" {
  run bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include commands
    PATH=/nonexistent commands::use definitely_not_a_real_command_xyz
  "
  [ "$status" -ne 0 ]
}
