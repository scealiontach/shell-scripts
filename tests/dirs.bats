#!/usr/bin/env bats
# SUR-1850 seed: dirs::safe_rmrf refusal contracts.

setup() {
  load 'helpers.bash'
  helpers::isolate_home
}

@test "dirs::safe_rmrf refuses empty, dot, dotdot, slash, double-slash, tilde" {
  for bad in '' '.' '..' '/' '//' '~'; do
    run bash -c "
      source '$REPO_ROOT/bash/includer.sh'
      @include dirs
      dirs::safe_rmrf '$bad'
    "
    [ "$status" -ne 0 ] || {
      echo "expected refusal for [$bad]" >&2
      false
    }
  done
}

@test "dirs::safe_rmrf refuses paths containing glob metacharacters" {
  for bad in 'foo*' 'foo?' 'foo[bar'; do
    run bash -c "
      source '$REPO_ROOT/bash/includer.sh'
      @include dirs
      dirs::safe_rmrf '$bad'
    "
    [ "$status" -ne 0 ] || {
      echo "expected refusal for [$bad]" >&2
      false
    }
  done
}

@test "dirs::safe_rmrf refuses to delete \$HOME" {
  run bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include dirs
    dirs::safe_rmrf \"\$HOME\"
  "
  [ "$status" -ne 0 ]
}

@test "dirs::safe_rmrf removes a real tempdir" {
  d=$(mktemp -d)
  echo content >"$d/file"
  run bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include dirs
    dirs::safe_rmrf '$d'
  "
  [ "$status" -eq 0 ]
  [ ! -e "$d" ]
}
