#!/usr/bin/env bats
# SUR-1881: secret.sh — register/materialise/shred lifecycle.

setup() {
  load 'helpers.bash'
  helpers::isolate_home
}

@test "secret::register_env + secret::exists returns 0 for a set env var" {
  run bash -c "
    MY_SECRET=hunter2
    source '$REPO_ROOT/bash/includer.sh'
    @include secret
    secret::register_env MY_SECRET
    secret::exists MY_SECRET
  "
  [ "$status" -eq 0 ]
}

@test "secret::as_file creates a readable tempfile for an env-backed secret" {
  run bash -c "
    MY_SECRET=hunter2
    LOGFILE_DISABLE=true
    source '$REPO_ROOT/bash/includer.sh'
    @include secret
    secret::register_env MY_SECRET
    tf=\$(secret::as_file MY_SECRET 2>/dev/null)
    [ -r \"\$tf\" ]
  "
  [ "$status" -eq 0 ]
}

@test "secret::as_file tempfile is shredded after subshell EXIT" {
  # Run in a $() subshell so the EXIT trap fires on subshell exit.
  # stdout-only capture avoids log noise polluting the path value.
  tf=$(bash -c "
    MY_SECRET=hunter2
    LOGFILE_DISABLE=true
    source '$REPO_ROOT/bash/includer.sh'
    @include secret
    secret::register_env MY_SECRET
    secret::as_file MY_SECRET 2>/dev/null
  ")
  [ -n "$tf" ]
  [ ! -e "$tf" ]
}

@test "secret::must_exist exits non-zero for an unregistered name" {
  run bash -c "
    LOGFILE_DISABLE=true
    source '$REPO_ROOT/bash/includer.sh'
    @include secret
    secret::must_exist UNREGISTERED_SECRET_XYZ
  "
  [ "$status" -ne 0 ]
}
