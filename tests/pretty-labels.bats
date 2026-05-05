#!/usr/bin/env bats
# SUR-1882: pretty-labels prints one label per line with the resource name
# column-padded, using a stubbed kubectl that returns fixture show-labels output.

setup() {
  load 'helpers.bash'
  helpers::isolate_home
  STUB_BIN=$(mktemp -d)
  # Stub kubectl mimics real kubectl: emits a header row unless
  # --no-headers is in the args. Lets us assert pretty-labels passes
  # --no-headers correctly (SUR-2332).
  cat >"$STUB_BIN/kubectl" <<'STUB'
#!/usr/bin/env bash
no_headers=false
for a in "$@"; do
  [[ "$a" == "--no-headers" ]] && no_headers=true
done
if ! $no_headers; then
  printf "NAME READY STATUS RESTARTS AGE LABELS\n"
fi
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

# SUR-2332: pre-fix, pretty-labels did not pass --no-headers to kubectl,
# so the kubectl header row "NAME ... LABELS" survived the awk extraction
# as the junk row "NAME:LABELS" and rendered one stray pair per
# invocation.
@test "pretty-labels does not emit the kubectl header row (SUR-2332)" {
  run bash -c "
    LOGFILE_DISABLE=true
    unset _kubectl
    '$REPO_ROOT/bash/pretty-labels' -t pod
  "
  [ "$status" -eq 0 ]
  [[ "$output" != *"LABELS"* ]]
  [[ "$output" != *"NAME"* ]]
}
