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

# SUR-2342: bash variable names reject hyphens and dots, so the cache-key
# variable name must be sanitised. Pre-fix, `commands::use ssh-keygen`
# crashed with `declare: '_ssh-keygen=...': not a valid identifier`.
@test "commands::use resolves a hyphenated command name (SUR-2342)" {
  STUB_BIN=$(mktemp -d)
  cat >"$STUB_BIN/ssh-keygen" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$STUB_BIN/ssh-keygen"
  out=$(mktemp)
  run env "PATH=$STUB_BIN:$PATH" bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include commands
    commands::use ssh-keygen >'$out'
  "
  rm -rf "$STUB_BIN"
  [ "$status" -eq 0 ]
  resolved=$(cat "$out")
  rm -f "$out"
  [[ "$resolved" == */ssh-keygen ]]
}

@test "commands::use resolves a dotted command name (SUR-2342)" {
  STUB_BIN=$(mktemp -d)
  cat >"$STUB_BIN/python3.12" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$STUB_BIN/python3.12"
  out=$(mktemp)
  run env "PATH=$STUB_BIN:$PATH" bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include commands
    commands::use python3.12 >'$out'
  "
  rm -rf "$STUB_BIN"
  [ "$status" -eq 0 ]
  resolved=$(cat "$out")
  rm -f "$out"
  [[ "$resolved" == */python3.12 ]]
}

@test "commands::use caches under sanitised key and survives binary removal (SUR-2342)" {
  # First call resolves and caches under _ssh_keygen. After the stub is
  # deleted, a second call must still return the cached path rather than
  # re-resolving. $() is a subshell so we redirect to a tempfile to keep
  # the declare -g cache write in the same shell.
  STUB_BIN=$(mktemp -d)
  cat >"$STUB_BIN/ssh-keygen" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$STUB_BIN/ssh-keygen"
  first="$BATS_TEST_TMPDIR/first"
  second="$BATS_TEST_TMPDIR/second"
  rm -f "$first" "$second"
  run env "PATH=$STUB_BIN:$PATH" bash -c "
    source '$REPO_ROOT/bash/includer.sh'
    @include commands
    commands::use ssh-keygen >'$first'
    rm -f '$STUB_BIN/ssh-keygen'
    commands::use ssh-keygen >'$second'
    [ \"\$_ssh_keygen\" = \"\$(cat '$first')\" ] || { echo 'cache key mismatch' >&2; exit 1; }
  "
  rm -rf "$STUB_BIN"
  [ "$status" -eq 0 ]
  p1=$(cat "$first")
  p2=$(cat "$second")
  [ "$p1" = "$p2" ]
  [[ "$p1" == */ssh-keygen ]]
}
