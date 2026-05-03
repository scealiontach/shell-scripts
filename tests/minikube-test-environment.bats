#!/usr/bin/env bats
# SUR-2184: shallow coverage for bash/minikube-test-environment — help output,
# env defaults, unknown-command path, and stubbed external tools (PATH prefix)
# mirroring tests/kind-test-environment.bats hermetic style.

setup() {
  load 'helpers.bash'
  helpers::isolate_home
  STUB_BIN=$(mktemp -d)
  MINIKUBE_ARGV_LOG=$(mktemp)
  cat >"$STUB_BIN/minikube" <<'STUB_EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >>"$MINIKUBE_ARGV_LOG"
exit 0
STUB_EOF
  for stub_name in kubectl helm jq daemonize; do
    printf '%s\n' '#!/usr/bin/env bash' 'exit 0' >"$STUB_BIN/$stub_name"
    chmod +x "$STUB_BIN/$stub_name"
  done
  chmod +x "$STUB_BIN/minikube"
  PATH="$STUB_BIN:$PATH"
  export STUB_BIN MINIKUBE_ARGV_LOG PATH
  MK_ENV="$REPO_ROOT/bash/minikube-test-environment"
}

teardown() {
  rm -rf "$STUB_BIN"
  rm -f "$MINIKUBE_ARGV_LOG"
}

@test "help lists defaults including MINIKUBE_DRIVER=docker" {
  run "$MK_ENV" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"MINIKUBE_DRIVER=docker"* ]]
  [[ "$output" == *"KUBERNETES_VERSION="* ]]
  [[ "$output" == *create* ]] && [[ "$output" == *stop* ]] && [[ "$output" == *delete* ]]
}

@test "help reflects MINIKUBE_DRIVER override from the environment" {
  run env MINIKUBE_DRIVER=podman "$MK_ENV" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"MINIKUBE_DRIVER=podman"* ]]
}

@test "bare invocation runs help" {
  run "$MK_ENV"
  [ "$status" -eq 0 ]
  [[ "$output" == *"MINIKUBE_DRIVER=docker"* ]]
}

@test "unknown command exits 1 and prints allowed commands" {
  run "$MK_ENV" not-a-command
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown command"* ]]
  [[ "$output" == *create* ]] && [[ "$output" == *stop* ]] && [[ "$output" == *delete* ]]
}

@test "stop invokes minikube stop with stubs on PATH" {
  run env "PATH=$PATH" "MINIKUBE_ARGV_LOG=$MINIKUBE_ARGV_LOG" "$MK_ENV" stop
  [ "$status" -eq 0 ]
  grep -qx 'stop' "$MINIKUBE_ARGV_LOG"
}
