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
    source '$REPO_ROOT/bash/includer.sh'
    @include secret
    secret::register_env MY_SECRET
    tf=\$(secret::as_file MY_SECRET 2>/dev/null)
    [ -r \"\$tf\" ] && [ \"\$(cat \"\$tf\")\" = hunter2 ]
  "
  [ "$status" -eq 0 ]
}

@test "secret::as_file preserves the trailing newline on disk (SUR-1930)" {
  # The original printenv-based implementation always emitted a trailing
  # newline. The indirect-expansion replacement must preserve that on-disk
  # contract for line-oriented consumers (PEM-style readers, etc.).
  # \$(cat) strips trailing newlines, so copy the tempfile out before the
  # EXIT trap shreds it and assert raw byte length.
  bash -c "
    MY_SECRET=hunter2
    source '$REPO_ROOT/bash/includer.sh'
    @include secret
    secret::register_env MY_SECRET
    tf=\$(secret::as_file MY_SECRET 2>/dev/null)
    cp \"\$tf\" '$BATS_TEST_TMPDIR/probe'
  "
  bytes=$(wc -c <"$BATS_TEST_TMPDIR/probe")
  # 'hunter2' is 7 bytes; with trailing \n that's 8.
  [ "$bytes" -eq 8 ]
}

@test "secret::as_file works for non-exported register_env (SUR-1930)" {
  # Caller deliberately does NOT 'export' MY_SECRET. The previous printenv
  # implementation produced a 0-byte file in this case. Indirect expansion
  # must read the variable regardless.
  out=$(bash -c "
    MY_SECRET=hunter2
    source '$REPO_ROOT/bash/includer.sh'
    @include secret
    secret::register_env MY_SECRET
    tf=\$(secret::as_file MY_SECRET 2>/dev/null)
    cat \"\$tf\"
  ")
  [ "$out" = "hunter2" ]
}

@test "secret::as_file works for two-arg register_env nameref (SUR-1930)" {
  out=$(bash -c "
    REAL=hunter2
    source '$REPO_ROOT/bash/includer.sh'
    @include secret
    secret::register_env ALIAS REAL
    tf=\$(secret::as_file ALIAS 2>/dev/null)
    cat \"\$tf\"
  ")
  [ "$out" = "hunter2" ]
}

@test "secret::as_file tempfile is shredded after subshell EXIT" {
  # Run in a $() subshell so the EXIT trap fires on subshell exit.
  # stdout-only capture avoids log noise polluting the path value.
  tf=$(bash -c "
    MY_SECRET=hunter2
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
    source '$REPO_ROOT/bash/includer.sh'
    @include secret
    secret::must_exist UNREGISTERED_SECRET_XYZ
  "
  [ "$status" -ne 0 ]
}
