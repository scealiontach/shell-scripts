#!/usr/bin/env bats
# Static structural assertions for bash/aliases update_* functions (SUR-1863).
# These tests grep the source to confirm security-critical properties without
# executing network-dependent code.

setup() {
  load 'helpers.bash'
  helpers::isolate_home
  ALIASES="$REPO_ROOT/bash/aliases"
  export ALIASES
}

# ---------- update_eksctl ------------------------------------------------------

@test "update_eksctl declares tmpdir as local" {
  run awk '/^function update_eksctl/,/^}$/' "$ALIASES"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "local tmpdir" ]]
}

@test "update_eksctl has trap RETURN cleanup" {
  run awk '/^function update_eksctl/,/^}$/' "$ALIASES"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "trap" ]] && [[ "$output" =~ "RETURN" ]]
}

@test "update_eksctl performs SHA-256 verification" {
  run awk '/^function update_eksctl/,/^}$/' "$ALIASES"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "sha256sum" ]]
}

@test "update_eksctl declares all loop variables as local" {
  run awk '/^function update_eksctl/,/^}$/' "$ALIASES"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "local arch" ]]
  [[ "$output" =~ "local os" ]]
}

# ---------- update_kubectl -----------------------------------------------------

@test "update_kubectl declares tmpdir as local" {
  run awk '/^function update_kubectl/,/^}$/' "$ALIASES"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "local tmpdir" ]]
}

@test "update_kubectl has trap RETURN cleanup" {
  run awk '/^function update_kubectl/,/^}$/' "$ALIASES"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "trap" ]] && [[ "$output" =~ "RETURN" ]]
}

@test "update_kubectl performs SHA-256 verification" {
  run awk '/^function update_kubectl/,/^}$/' "$ALIASES"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "sha256sum" ]]
}

@test "update_kubectl declares arch and os as local" {
  run awk '/^function update_kubectl/,/^}$/' "$ALIASES"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "local arch" ]]
  [[ "$output" =~ "local os" ]]
}

@test "update_kubectl installs with install command not cd-and-mv" {
  # The old implementation used: cd "\${tmpdir}"; chmod; mv; cd - || return
  # The rewrite must use 'install -m 0755' instead.
  run awk '/^function update_kubectl/,/^}$/' "$ALIASES"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "install -m 0755" ]]
}
