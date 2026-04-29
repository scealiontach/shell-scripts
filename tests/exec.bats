#!/usr/bin/env bats
# SUR-1860: exec::capture must not leak `exit_code` into caller scope.
# Caller pre-sets exit_code=999; after exec::capture returns, $exit_code
# in the caller must remain 999. Return code must equal the wrapped
# command's exit code.

setup() {
  load 'helpers.bash'
  helpers::isolate_home
}

@test "exec::capture preserves caller's exit_code on success" {
  out=$(bash -c "
    LOGFILE_DISABLE=true
    source '$REPO_ROOT/bash/includer.sh'
    @include exec
    exit_code=999
    exec::capture true >/dev/null
    rc=\$?
    echo \"exit_code=\$exit_code rc=\$rc\"
  ")
  [[ "$out" == "exit_code=999 rc=0" ]]
}

@test "exec::capture preserves caller's exit_code on failure" {
  out=$(bash -c "
    LOGFILE_DISABLE=true
    source '$REPO_ROOT/bash/includer.sh'
    @include exec
    exit_code=999
    exec::capture bash -c 'exit 7' >/dev/null
    rc=\$?
    echo \"exit_code=\$exit_code rc=\$rc\"
  ")
  [[ "$out" == "exit_code=999 rc=7" ]]
}

@test "exec::capture returns wrapped command's exit code via the tee branch" {
  # Tee branch: LOGFILE_DISABLE unset/false. LOGFILE redirected into the
  # tmp HOME so we don't pollute the repo.
  out=$(bash -c "
    LOGFILE='$HOME/exec.log'
    source '$REPO_ROOT/bash/includer.sh'
    @include exec
    exit_code=999
    exec::capture bash -c 'exit 5' >/dev/null
    rc=\$?
    echo \"exit_code=\$exit_code rc=\$rc\"
  ")
  [[ "$out" == "exit_code=999 rc=5" ]]
}

@test "exec::capture leaves exit_code unset in a fresh caller scope" {
  # Caller never set exit_code; after exec::capture, exit_code must
  # still be unset (the function's local must not bleed out).
  out=$(bash -c "
    LOGFILE_DISABLE=true
    source '$REPO_ROOT/bash/includer.sh'
    @include exec
    unset exit_code
    exec::capture true >/dev/null
    if declare -p exit_code >/dev/null 2>&1; then
      echo 'LEAKED'
    else
      echo 'OK'
    fi
  ")
  [[ "$out" == "OK" ]]
}
