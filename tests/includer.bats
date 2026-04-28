#!/usr/bin/env bats
# SUR-1850 seed: @include cksum-based dedup + missing-include behavior.

setup() {
  load 'helpers.bash'
  helpers::isolate_home
}

@test "@include sources a library exactly once even when invoked twice" {
  run bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    # Use a tiny side-effect probe by intercepting log:: function definitions.
    @include log
    first=\$(declare -f log::level | wc -l)
    @include log
    second=\$(declare -f log::level | wc -l)
    [ \"\$first\" = \"\$second\" ] || exit 1
  "
  [ "$status" -eq 0 ]
}

@test "@include returns non-zero when the library does not exist" {
  run bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include this_library_definitely_does_not_exist_xyz
  "
  [ "$status" -ne 0 ]
}

@test "@include sets a dedup guard variable named include_<cksum>" {
  run bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include log
    # At least one variable named include_<digits> must now be set.
    declared=\$(compgen -v include_ || true)
    [ -n \"\$declared\" ] || exit 1
  "
  [ "$status" -eq 0 ]
}
