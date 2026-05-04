#!/usr/bin/env bats
# SUR-2234: fetch-all-pod-logs kubectl/jq command lines and log file naming.

setup() {
  load 'helpers.bash'
  helpers::isolate_home
  export LOGFILE_DISABLE=true
  SCRIPT="$REPO_ROOT/bash/fetch-all-pod-logs"
  STUB_BIN=$(mktemp -d)
  KUBECTL_LOG=$(mktemp)
  JQ_ARGV_LOG=$(mktemp)
  export JQ_ARGV_LOG
  cat >"$STUB_BIN/kubectl" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$KUBECTL_LOG"
case "\$*" in
  *"get pods"*)
    printf '%s' '{"items":[{"metadata":{"name":"pod-a"}},{"metadata":{"name":"pod-b"}}]}'
    ;;
  *" logs "*)
    printf 'logline\n'
    ;;
esac
STUB
  chmod +x "$STUB_BIN/kubectl"

  cat >"$STUB_BIN/jq" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$JQ_ARGV_LOG"
cat >/dev/null
printf '%s\n' pod-a pod-b
STUB
  chmod +x "$STUB_BIN/jq"

  export PATH="$STUB_BIN:$PATH"
  unset _kubectl _jq
  FETCH_TEST_CWD=$(mktemp -d)
}

teardown() {
  rm -rf "$STUB_BIN" "$FETCH_TEST_CWD"
  rm -f "$KUBECTL_LOG" "$JQ_ARGV_LOG"
}

@test "invokes kubectl get pods with -l selector and namespace" {
  cd "$FETCH_TEST_CWD" || false
  run "$SCRIPT" -l 'app=myapp' -n 'ns-one'
  [ "$status" -eq 0 ]
  grep -Fq 'get pods -n ns-one -l app=myapp -o json' "$KUBECTL_LOG"
  grep -Fq ".items[].metadata.name" "$JQ_ARGV_LOG"
}

@test "writes pod log files with .all suffix when -c is omitted" {
  cd "$FETCH_TEST_CWD" || false
  run "$SCRIPT" -l 'role=worker'
  [ "$status" -eq 0 ]
  [ -f pod-a.all.out ]
  [ -f pod-b.all.out ]
  grep -Fq 'logs pod-a --tail=10000 --timestamps --all-containers --max-log-requests=100' "$KUBECTL_LOG"
  grep -Fq 'logs pod-b --tail=10000 --timestamps --all-containers --max-log-requests=100' "$KUBECTL_LOG"
}

@test "passes -c to kubectl logs and uses suffix in output filename" {
  cd "$FETCH_TEST_CWD" || false
  run "$SCRIPT" -l 'app=x' -c 'sidecar'
  [ "$status" -eq 0 ]
  [ -f pod-a.sidecar.out ]
  grep -Fq 'logs pod-a --tail=10000 --timestamps -c sidecar' "$KUBECTL_LOG"
}
