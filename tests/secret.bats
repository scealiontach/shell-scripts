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

# SUR-2324: secret::_install_cleanup_trap must chain (not clobber) any
# caller-installed EXIT trap. Pre-fix, the unconditional
# `trap 'secret::clear' EXIT INT TERM` overwrote the caller's trap and
# the caller's cleanup never fired, leaking resources.
@test "secret::register_env preserves caller's pre-existing EXIT trap (SUR-2324)" {
  SENTINEL="$BATS_TEST_TMPDIR/exit-sentinel"
  TMPFILE_PROBE="$BATS_TEST_TMPDIR/tmpfile-probe"
  rm -f "$SENTINEL" "$TMPFILE_PROBE"
  # secret::as_file must run in the outer shell (not via $()) so the
  # tempfile path lands in SECRET_TMPFILES of the same shell whose EXIT
  # trap will later run secret::clear. We redirect stdout to a probe file
  # so the test can read the path after the subshell exits.
  bash -c "
    trap 'touch \"$SENTINEL\"' EXIT
    MY_SECRET=hunter2
    source '$REPO_ROOT/bash/includer.sh'
    @include secret
    secret::register_env MY_SECRET
    secret::as_file MY_SECRET 2>/dev/null >'$TMPFILE_PROBE'
  "
  # Caller's EXIT trap fired (sentinel created).
  [ -f "$SENTINEL" ]
  # secret::clear also ran (the tempfile is gone).
  tf=$(cat "$TMPFILE_PROBE")
  [ -n "$tf" ]
  [ ! -e "$tf" ]
}

# SUR-2324: caller-trap commands containing single quotes are escaped by
# `trap -p` as '\''; the chained-trap eval must unescape them correctly.
@test "secret::_install_cleanup_trap survives a caller trap with embedded single quotes (SUR-2324)" {
  SENTINEL="$BATS_TEST_TMPDIR/quoted-sentinel"
  rm -f "$SENTINEL"
  bash -c "
    trap 'echo '\\''quoted-trap-fired'\\'' >\"$SENTINEL\"' EXIT
    MY_SECRET=hunter2
    source '$REPO_ROOT/bash/includer.sh'
    @include secret
    secret::register_env MY_SECRET
  "
  [ -f "$SENTINEL" ]
  out=$(cat "$SENTINEL")
  [ "$out" = "quoted-trap-fired" ]
}

# SUR-2830: secret::clear must use array length, not [0]. A sparse array
# (element 0 unset, later indices populated) previously made the guard
# fail and the cleanup silently no-op, leaving 0600 tempfiles with secret
# material under $TMPDIR.
@test "secret::clear removes tempfiles when SECRET_TMPFILES[0] is unset (SUR-2830)" {
  PROBE_DIR="$BATS_TEST_TMPDIR/sparse"
  mkdir -p "$PROBE_DIR"
  a="$PROBE_DIR/a"
  b="$PROBE_DIR/b"
  : >"$a"
  : >"$b"
  bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include secret
    SECRET_TMPFILES=('$a' '$b')
    unset 'SECRET_TMPFILES[0]'
    secret::clear
  "
  [ ! -e "$a" ] || [ ! -e "$b" ] # at least the surviving index was removed
  [ ! -e "$b" ]
}

# SUR-2324: idempotency — installing twice must not stack chained calls.
@test "secret::_install_cleanup_trap is idempotent within a shell (SUR-2324)" {
  SENTINEL="$BATS_TEST_TMPDIR/idempotent-sentinel"
  rm -f "$SENTINEL"
  bash -c "
    trap 'printf x >>\"$SENTINEL\"' EXIT
    MY_SECRET=hunter2
    OTHER_SECRET=passw0rd
    source '$REPO_ROOT/bash/includer.sh'
    @include secret
    secret::register_env MY_SECRET
    secret::register_env OTHER_SECRET
  "
  # Caller's trap should fire exactly once on shell exit.
  out=$(cat "$SENTINEL")
  [ "$out" = "x" ]
}
