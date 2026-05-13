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

@test "exec::hide swallows stdout" {
  out=$(bash -c "
    LOGFILE_DISABLE=true
    source '$REPO_ROOT/bash/includer.sh'
    @include exec
    exec::hide bash -c 'echo stdout-hidden'
    echo visible
  ")
  [[ "$out" == "visible" ]]
  [[ "$out" != *"stdout-hidden"* ]]
}

@test "exec::hide swallows stderr" {
  out=$(bash -c "
    LOGFILE_DISABLE=true
    source '$REPO_ROOT/bash/includer.sh'
    @include exec
    exec::hide bash -c 'echo stderr-hidden >&2'
    echo visible
  " 2>&1)
  [[ "$out" == "visible" ]]
  [[ "$out" != *"stderr-hidden"* ]]
}

@test "exec::hide preserves zero exit code" {
  run bash -c "
    LOGFILE_DISABLE=true
    source '$REPO_ROOT/bash/includer.sh'
    @include exec
    exec::hide true
  "
  [ "$status" -eq 0 ]
}

@test "exec::hide preserves non-zero exit code" {
  run bash -c "
    LOGFILE_DISABLE=true
    source '$REPO_ROOT/bash/includer.sh'
    @include exec
    exec::hide bash -c 'exit 7'
  "
  [ "$status" -eq 7 ]
}

@test "exec_and_hide delegates stdout suppression to exec::hide" {
  out=$(bash -c "
    LOGFILE_DISABLE=true
    source '$REPO_ROOT/bash/includer.sh'
    @include exec
    exec_and_hide bash -c 'echo stdout-hidden'
    echo visible
  " 2>/dev/null)
  [[ "$out" == "visible" ]]
  [[ "$out" != *"stdout-hidden"* ]]
}

@test "exec_and_capture delegates exit code preservation to exec::capture" {
  run bash -c "
    LOGFILE_DISABLE=true
    source '$REPO_ROOT/bash/includer.sh'
    @include exec
    exec_and_capture bash -c 'exit 3' >/dev/null
  "
  [ "$status" -eq 3 ]
}

@test "exec::capture writes wrapped command's stdout to caller" {
  out=$(bash -c "
    LOGFILE_DISABLE=true
    source '$REPO_ROOT/bash/includer.sh'
    @include exec
    exec::capture echo hello
  ")
  [[ "$out" == "hello" ]]
}

@test "exec::capture passes stdout through via the tee branch" {
  out=$(bash -c "
    LOGFILE='$HOME/exec-tee.log'
    source '$REPO_ROOT/bash/includer.sh'
    @include exec
    exec::capture echo hello
  ")
  [[ "$out" == "hello" ]]
}

@test "exec::capture populates exec_output with the command's stdout" {
  run bash -c "
    LOGFILE_DISABLE=true
    source '${REPO_ROOT}/bash/includer.sh'
    @include exec
    exec::capture echo hello >/dev/null
    printf '%s' \"\$exec_output\"
  "
  [ "$output" = "hello" ]
}

# SUR-2831: exec::capture must not install a RETURN trap that leaks into
# the caller's scope. The previous `trap 'rm -f "$tmpout"' RETURN` was
# never cleared, occupied the trap slot permanently, and overwrote any
# caller-installed RETURN trap (last-writer-wins).

@test "exec::capture leaves no RETURN trap installed in caller scope (SUR-2831)" {
  out=$(bash -c "
    LOGFILE='\$HOME/exec.log'
    source '$REPO_ROOT/bash/includer.sh'
    @include exec
    caller() {
      exec::capture true >/dev/null
      trap -p RETURN
    }
    caller
  ")
  [ -z "$out" ]
}

@test "exec::capture does not clobber a caller-installed RETURN trap (SUR-2831)" {
  SENTINEL="$BATS_TEST_TMPDIR/return-sentinel"
  rm -f "$SENTINEL"
  bash -c "
    LOGFILE='\$HOME/exec.log'
    source '$REPO_ROOT/bash/includer.sh'
    @include exec
    caller() {
      trap 'touch \"$SENTINEL\"' RETURN
      exec::capture true >/dev/null
    }
    caller
  "
  [ -f "$SENTINEL" ]
}

@test "exec::capture populates exec_output via the tee branch" {
  run bash -c "
    LOGFILE='$HOME/exec-tee-output.log'
    source '${REPO_ROOT}/bash/includer.sh'
    @include exec
    exec::capture echo world >/dev/null
    printf '%s' \"\$exec_output\"
  "
  [ "$output" = "world" ]
}
