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

# SUR-2330: update_kubectl must create ~/.local/bin if missing (peers
# update_eksctl/update_helm already do). Without this, install(1) hard-fails
# with "No such file or directory" on a fresh machine.
@test "update_kubectl creates ~/.local/bin before installing (SUR-2330)" {
  run awk '/^function update_kubectl/,/^}$/' "$ALIASES"
  [ "$status" -eq 0 ]
  # Single quotes are intentional: the source contains the literal `$HOME`,
  # not its expansion.
  # shellcheck disable=SC2016
  [[ "$output" == *'mkdir -p "$HOME/.local/bin"'* ]]
}

@test "update_kubectl succeeds when ~/.local/bin does not pre-exist (SUR-2330)" {
  # Stub curl so the network/verify path resolves against a local fake
  # "kubectl" payload, then run update_kubectl with HOME pointing at a
  # tmpdir that lacks .local/bin and assert the binary is installed.
  STUB_BIN=$(mktemp -d)
  FAKE_KUBECTL="$STUB_BIN/kubectl-payload"
  printf '#!/usr/bin/env bash\nexit 0\n' >"$FAKE_KUBECTL"
  FAKE_HASH=$(sha256sum "$FAKE_KUBECTL" | awk '{print $1}')

  cat >"$STUB_BIN/curl" <<EOF
#!/usr/bin/env bash
out=
while [ \$# -gt 0 ]; do
  case "\$1" in
    -o) out=\$2; shift 2 ;;
    -fsSL|-fsS|-s|-S|-L|-f) shift ;;
    *) url=\$1; shift ;;
  esac
done
case "\$url" in
  *kubectl.sha256) printf '%s' "$FAKE_HASH" >"\$out" ;;
  *kubectl)        cp "$FAKE_KUBECTL" "\$out" ;;
  *)               exit 1 ;;
esac
EOF
  chmod +x "$STUB_BIN/curl"

  # Confirm the isolated HOME does not already contain .local/bin.
  [ ! -d "$HOME/.local/bin" ]

  run env "PATH=$STUB_BIN:$PATH" KUBECTL_VERSION=v1.32.0 \
    bash -c "source '$ALIASES'; update_kubectl"
  [ "$status" -eq 0 ]
  [ -x "$HOME/.local/bin/kubectl" ]

  rm -rf "$STUB_BIN"
}

# ---------- get_latest_btp_branch (SUR-1928) ----------------------------------

@test "get_latest_btp_branch declares loop vars local (SUR-1928)" {
  run awk '/^function get_latest_btp_branch/,/^}$/' "$ALIASES"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "local d b branch" ]]
}

@test "get_latest_btp_branch does not leak \$branch to caller (SUR-1928)" {
  fixture=$(mktemp -d)
  mkdir -p "$fixture/repo-a/.git"

  stub_bin=$(mktemp -d)
  cat >"$stub_bin/git" <<'EOF'
#!/usr/bin/env bash
# git branch -la → emit one fake remote-tracking ref so the inner loop runs.
# git checkout … → no-op success.
case "$1 $2" in
  "branch -la")
    printf '  remotes/origin/btp-releases-2025-04\n'
    ;;
  "checkout "*)
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
EOF
  chmod +x "$stub_bin/git"

  PATH="$stub_bin:$PATH"
  cd "$fixture"
  branch=outer
  # shellcheck disable=SC1090
  source "$ALIASES"
  get_latest_btp_branch >/dev/null 2>&1 || true
  [ "$branch" = "outer" ]

  cd /
  rm -rf "$fixture" "$stub_bin"
}
