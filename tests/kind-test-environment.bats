#!/usr/bin/env bats
# SUR-1868: lock down bash/kind-test-environment — `::add_helm_repos`
# must keep its iteration variables (`repo`, `repo_name`, `repo_url`)
# function-local, and `::asdf` must keep `_asdf`, `_where`, `ret` local.

setup() {
  load 'helpers.bash'
  helpers::isolate_home
  STUB_BIN=$(mktemp -d)
  HELM_ARGV_LOG=$(mktemp)
  cat >"$STUB_BIN/helm" <<'STUB_EOF'
#!/usr/bin/env bash
echo "$@" >>"$HELM_ARGV_LOG"
STUB_EOF
  chmod +x "$STUB_BIN/helm"
  PATH="$STUB_BIN:$PATH"
  export STUB_BIN HELM_ARGV_LOG PATH
}

teardown() {
  rm -rf "$STUB_BIN"
  rm -f "$HELM_ARGV_LOG"
}

@test "::add_helm_repos forwards a 3-element repo list to helm and does not leak vars" {
  run env \
    "PATH=$PATH" \
    "HELM_ARGV_LOG=$HELM_ARGV_LOG" \
    "KIND_TEST_ENVIRONMENT_SOURCE_ONLY=true" \
    bash -c "
      source '$REPO_ROOT/bash/kind-test-environment' -c create
      # Reset after source so the script's own repo defaults don't
      # contaminate the test's controlled list.
      ADD_HELM_REPOS=(
        'alpha,https://alpha.example.com/'
        'bravo,https://bravo.example.com/'
        'charlie,https://charlie.example.com/'
      )
      ::add_helm_repos
      [ -z \"\${repo:-}\" ]      || { echo 'repo leaked' >&2; exit 1; }
      [ -z \"\${repo_name:-}\" ] || { echo 'repo_name leaked' >&2; exit 1; }
      [ -z \"\${repo_url:-}\" ]  || { echo 'repo_url leaked' >&2; exit 1; }
    "
  [ "$status" -eq 0 ]
  # 3 add invocations + 1 update invocation
  add_lines=$(grep -c "^repo add " "$HELM_ARGV_LOG")
  [ "$add_lines" -eq 3 ]
  grep -q "^repo add alpha https://alpha.example.com/$" "$HELM_ARGV_LOG"
  grep -q "^repo add bravo https://bravo.example.com/$" "$HELM_ARGV_LOG"
  grep -q "^repo add charlie https://charlie.example.com/$" "$HELM_ARGV_LOG"
  grep -q "^repo update$" "$HELM_ARGV_LOG"
}

@test "::asdf keeps _asdf, _where, ret function-local" {
  cat >"$STUB_BIN/asdf" <<'STUB_EOF'
#!/usr/bin/env bash
case "$1" in
  which)
    if [ "${2:-}" = "kind" ]; then
      echo "/fake/kind"
      exit 0
    fi
    exit 1
    ;;
  *) exit 0 ;;
esac
STUB_EOF
  chmod +x "$STUB_BIN/asdf"

  run env \
    "PATH=$PATH" \
    "KIND_TEST_ENVIRONMENT_SOURCE_ONLY=true" \
    bash -c "
      source '$REPO_ROOT/bash/kind-test-environment' -c create
      ::asdf kind
      [ -z \"\${_asdf:-}\" ]  || { echo '_asdf leaked' >&2; exit 1; }
      [ -z \"\${_where:-}\" ] || { echo '_where leaked' >&2; exit 1; }
      [ -z \"\${ret:-}\" ]    || { echo 'ret leaked' >&2; exit 1; }
    "
  [ "$status" -eq 0 ]
}
