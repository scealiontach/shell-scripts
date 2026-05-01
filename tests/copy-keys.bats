#!/usr/bin/env bats

setup() {
  load 'helpers.bash'
  helpers::isolate_home
  WORK=$(mktemp -d)
  cd "$WORK" || exit 1
  STUB_BIN="$REPO_ROOT/tests/stubs"
  STUB_JQ_DIR=$(mktemp -d)
  printf '%s\n' '#!/usr/bin/env bash' 'cat >/dev/null' 'echo stub-node' \
    >"$STUB_JQ_DIR/jq"
  chmod +x "$STUB_JQ_DIR/jq"
  KUBECTL_ARGV_LOG=$(mktemp)
  PATH="$STUB_JQ_DIR:$STUB_BIN:$PATH"
  unset _kubectl KUBECTL_CP_FAIL
  export PATH STUB_BIN KUBECTL_ARGV_LOG WORK STUB_JQ_DIR
  COPY_KEYS="$REPO_ROOT/bash/copy-keys"
  export COPY_KEYS
}

teardown() {
  rm -f "$KUBECTL_ARGV_LOG"
  rm -rf "$WORK" "$STUB_JQ_DIR"
}

@test "copy-keys overwrites existing pod symlinks and succeeds on rerun" {
  run bash "$COPY_KEYS" -l app=foo
  [[ "$status" -eq 0 ]]
  [[ -L keys/example-pod-1 ]]
  [[ -f keys/stub-node/validator.priv ]]

  run bash "$COPY_KEYS" -l app=foo
  [[ "$status" -eq 0 ]]
  [[ -L keys/example-pod-1 ]]
}

@test "copy-keys exits non-zero when kubectl cp fails" {
  export KUBECTL_CP_FAIL=1
  run bash "$COPY_KEYS" -l app=foo
  [[ "$status" -ne 0 ]]
}
