#!/usr/bin/env bats
# SUR-1882: pretty-labels prints one label per line with the resource name
# column-padded, using a stubbed kubectl that returns fixture show-labels output.

setup() {
  load 'helpers.bash'
  helpers::isolate_home
  STUB_BIN=$(mktemp -d)
  cat >"$STUB_BIN/kubectl" <<'STUB'
#!/usr/bin/env bash
printf "NAME READY STATUS RESTARTS AGE LABELS\n"
printf "mypod-1 1/1 Running 0 1d app=myapp,tier=frontend\n"
STUB
  chmod +x "$STUB_BIN/kubectl"
  PATH="$STUB_BIN:$PATH"
  unset _kubectl
  export STUB_BIN PATH
}

teardown() {
  rm -rf "$STUB_BIN"
}

@test "pretty-labels prints resource name on each label line" {
  run bash -c "
    LOGFILE_DISABLE=true
    unset _kubectl
    '$REPO_ROOT/bash/pretty-labels' -t pod
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"mypod-1"* ]]
}

@test "pretty-labels prints one label per line" {
  run bash -c "
    LOGFILE_DISABLE=true
    unset _kubectl
    '$REPO_ROOT/bash/pretty-labels' -t pod
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"app=myapp"* ]]
  [[ "$output" == *"tier=frontend"* ]]
}
