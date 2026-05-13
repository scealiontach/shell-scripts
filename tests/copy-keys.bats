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

# SUR-2827: -n NAMESPACE was threaded only into the initial
# k8s::pod_names_for_label call. Every downstream `get pod` and `cp`
# invocation silently dropped the namespace, copying key material from
# the wrong pod (or failing to find one).
@test "copy-keys forwards -n NAMESPACE to every kubectl call (SUR-2827)" {
  run bash "$COPY_KEYS" -l app=foo -n my-ns
  [[ "$status" -eq 0 ]]
  # Every recorded kubectl invocation must carry `-n my-ns`. The recording
  # stub appends "$@" one line per call.
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    [[ "$line" == *"-n my-ns"* ]] || {
      echo "missing -n my-ns in: $line"
      return 1
    }
  done <"$KUBECTL_ARGV_LOG"
  # Sanity-check we actually recorded the downstream `get pod` and `cp`
  # calls, not just the initial pod list lookup.
  grep -q "^get pod " "$KUBECTL_ARGV_LOG"
  grep -q "^cp " "$KUBECTL_ARGV_LOG"
}

@test "copy-keys passes no -n flag when NAMESPACE is unset (SUR-2827)" {
  run bash "$COPY_KEYS" -l app=foo
  [[ "$status" -eq 0 ]]
  # No invocation should contain `-n ` (with trailing space) since the
  # stub never receives a namespace argument.
  run ! grep -q -- " -n " "$KUBECTL_ARGV_LOG"
}
