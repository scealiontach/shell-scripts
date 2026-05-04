#!/usr/bin/env bats
# SUR-2179: regression coverage for bash/on-change — options, defaults,
# post-`--` argv to the watched command, and stable error paths (no wall-clock
# assertions on the polling loop itself).

setup() {
  load 'helpers.bash'
  helpers::isolate_home
  ONCHANGE="$REPO_ROOT/bash/on-change"
  ONCHANGE_REAL_SLEEP=$(command -v sleep) || true
  export ONCHANGE_REAL_SLEEP
}

@test "bare invocation prints syntax and exits 1" {
  run "$ONCHANGE"
  [ "$status" -eq 1 ]
  [[ "$output" == *SYNTAX* ]] || [[ "$output" == *OPTIONS* ]]
}

@test "-h prints help and exits 1" {
  run "$ONCHANGE" -h
  [ "$status" -eq 1 ]
  [[ "$output" == *SYNTAX* ]] || [[ "$output" == *OPTIONS* ]]
  [[ "$output" == *"-W"* ]] && [[ "$output" == *"-w"* ]] && [[ "$output" == *"-t"* ]]
}

@test "missing WorkingDir surfaces not-found error" {
  watch_dir=$(mktemp -d)
  run "$ONCHANGE" -W "$watch_dir" -w "/no/such/working/dir" -t 9 -- true
  rm -rf "$watch_dir"
  [ "$status" -eq 1 ]
  [[ "$output" == *"/no/such/working/dir not found"* ]]
}

@test "WorkingDir defaults to WatchDir when -w is omitted" {
  watch_dir=$(mktemp -d)
  touch "$watch_dir/seed"
  argv_log=$(mktemp)
  stub_bin=$(mktemp -d)
  cat >"$stub_bin/record_argv" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$@" >>"$argv_log"
EOF
  chmod +x "$stub_bin/record_argv"
  (
    sleep 0.4
    echo trigger >>"$watch_dir/marker"
  ) &
  run env PATH="$stub_bin:$PATH" timeout 8s "$ONCHANGE" -W "$watch_dir" -t 1 -v -v -- "$stub_bin/record_argv" ok
  [[ "$output" == *"Working directory $watch_dir"* ]]
  [[ "$output" == *"Watching directory $watch_dir"* ]]
  [[ "$output" == *"Polling interval 1"* ]]
  grep -qx 'ok' "$argv_log"
  rm -rf "$watch_dir" "$stub_bin"
  rm -f "$argv_log"
}

@test "argv after -- is passed unchanged to the invoked command" {
  watch_dir=$(mktemp -d)
  touch "$watch_dir/seed"
  argv_log=$(mktemp)
  stub_bin=$(mktemp -d)
  cat >"$stub_bin/record_argv" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$@" >>"$argv_log"
EOF
  chmod +x "$stub_bin/record_argv"
  (
    sleep 0.4
    echo trigger >>"$watch_dir/marker"
  ) &
  run env PATH="$stub_bin:$PATH" timeout 8s "$ONCHANGE" -W "$watch_dir" -w "$watch_dir" -t 1 -- "$stub_bin/record_argv" "arg one" "arg two"
  grep -qx 'arg one' "$argv_log"
  grep -qx 'arg two' "$argv_log"
  rm -rf "$watch_dir" "$stub_bin"
  rm -f "$argv_log"
}

@test "SUR-2242: closed stdin throttles polling via sleep (no tight find loop)" {
  [ -n "$ONCHANGE_REAL_SLEEP" ] || skip "sleep not on PATH"
  watch_dir=$(mktemp -d)
  touch "$watch_dir/seed"
  stub_bin=$(mktemp -d)
  sleep_log=$(mktemp)
  cat >"$stub_bin/sleep" <<EOF
#!/usr/bin/env bash
printf 'x\n' >>"$sleep_log"
exec "$ONCHANGE_REAL_SLEEP" "\$@"
EOF
  chmod +x "$stub_bin/sleep"
  (
    "$ONCHANGE_REAL_SLEEP" 2
    echo trig >>"$watch_dir/marker"
  ) &
  run env PATH="$stub_bin:$PATH" timeout 8s "$ONCHANGE" -W "$watch_dir" -w "$watch_dir" -t 1 -- true </dev/null
  rm -rf "$watch_dir" "$stub_bin"
  n_sleep=$(wc -l <"$sleep_log")
  rm -f "$sleep_log"
  [ "$status" -eq 124 ]
  [ "$n_sleep" -ge 2 ]
  [ "$n_sleep" -le 12 ]
}

@test "SUR-2242: closed stdin sleep throttle uses WaitTime (not fixed 1s)" {
  [ -n "$ONCHANGE_REAL_SLEEP" ] || skip "sleep not on PATH"
  watch_dir=$(mktemp -d)
  touch "$watch_dir/seed"
  stub_bin=$(mktemp -d)
  sleep_log=$(mktemp)
  cat >"$stub_bin/sleep" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$sleep_log"
exec "$ONCHANGE_REAL_SLEEP" "\$@"
EOF
  chmod +x "$stub_bin/sleep"
  run env PATH="$stub_bin:$PATH" timeout 22s "$ONCHANGE" -W "$watch_dir" -w "$watch_dir" -t 60 -- true </dev/null
  rm -rf "$watch_dir" "$stub_bin"
  first_sleep=$(head -n 1 "$sleep_log")
  n_sleep=$(wc -l <"$sleep_log")
  rm -f "$sleep_log"
  [ "$status" -eq 124 ]
  [[ "$first_sleep" == 60 ]]
  [ "$n_sleep" -le 5 ]
}

@test "SUR-2242: fractional -t with closed stdin does not emit arithmetic errors" {
  watch_dir=$(mktemp -d)
  touch "$watch_dir/seed"
  (
    sleep 0.3
    echo trig >>"$watch_dir/marker"
  ) &
  run timeout 5s "$ONCHANGE" -W "$watch_dir" -w "$watch_dir" -t 1.5 -- true </dev/null 2>&1
  rm -rf "$watch_dir"
  [ "$status" -eq 124 ]
  [[ "$output" != *syntax*error* ]]
  [[ "$output" != *invalid*timeout* ]]
}

@test "SUR-2242: fractional -t with open stdin does not double-sleep after read timeout" {
  [ -n "$ONCHANGE_REAL_SLEEP" ] || skip "sleep not on PATH"
  watch_dir=$(mktemp -d)
  touch "$watch_dir/seed"
  fifo_dir=$(mktemp -d)
  fifo="$fifo_dir/pipe"
  mkfifo "$fifo"
  stub_bin=$(mktemp -d)
  sleep_log=$(mktemp)
  cat >"$stub_bin/sleep" <<EOF
#!/usr/bin/env bash
printf 'x\n' >>"$sleep_log"
exec "$ONCHANGE_REAL_SLEEP" "\$@"
EOF
  chmod +x "$stub_bin/sleep"
  # RDWR open: no peer needed; read -t blocks until timeout (no tight EOF).
  # Use fd 4 — bats reserves 3 for its own I/O.
  exec 4<>"$fifo"
  run env PATH="$stub_bin:$PATH" timeout 6s "$ONCHANGE" -W "$watch_dir" -w "$watch_dir" -t 1.2 -- true <&4
  exec 4>&- || true
  n_sleep=$(wc -l <"$sleep_log")
  rm -rf "$watch_dir" "$stub_bin" "$fifo_dir" "$sleep_log"
  [ "$status" -eq 124 ]
  [ "$n_sleep" -eq 0 ]
}

@test "SUR-2242: -t 0 with closed stdin throttles via sleep" {
  [ -n "$ONCHANGE_REAL_SLEEP" ] || skip "sleep not on PATH"
  watch_dir=$(mktemp -d)
  touch "$watch_dir/seed"
  stub_bin=$(mktemp -d)
  sleep_log=$(mktemp)
  cat >"$stub_bin/sleep" <<EOF
#!/usr/bin/env bash
printf 'x\n' >>"$sleep_log"
exec "$ONCHANGE_REAL_SLEEP" "\$@"
EOF
  chmod +x "$stub_bin/sleep"
  (
    "$ONCHANGE_REAL_SLEEP" 2
    echo trig >>"$watch_dir/marker"
  ) &
  run env PATH="$stub_bin:$PATH" timeout 5s "$ONCHANGE" -W "$watch_dir" -w "$watch_dir" -t 0 -- true </dev/null
  rm -rf "$watch_dir" "$stub_bin"
  n_sleep=$(wc -l <"$sleep_log")
  rm -f "$sleep_log"
  [ "$status" -eq 124 ]
  [ "$n_sleep" -ge 1 ]
}

@test "SUR-2242: bash 3.x follow-up read after -t 0 uses integer -t (fractional WaitTime)" {
  # Bash 3.2 rejects non-integer read -t; the non-TTY branch must cap the follow-up
  # read with ceil(WaitTime) so stdin cannot block forever (code review).
  [[ "${BASH_VERSINFO[0]}" -lt 4 ]] || skip "requires bash 3.x"
  watch_dir=$(mktemp -d)
  touch "$watch_dir/seed"
  run timeout 8s "$ONCHANGE" -W "$watch_dir" -w "$watch_dir" -t 2.5 -- true </dev/null 2>&1
  rm -rf "$watch_dir"
  [ "$status" -eq 124 ]
  [[ "$output" != *invalid*timeout* ]]
}

@test "SUR-2242: bash 3.x from PATH exercises fractional WaitTime + closed stdin (no invalid read -t)" {
  bash_major_3=
  for candidate in bash-3.2 bash32; do
    if command -v "$candidate" >/dev/null 2>&1; then
      bash_major_3=$(command -v "$candidate")
      break
    fi
  done
  [[ -n "$bash_major_3" ]] || skip "no bash-3.2 or bash32 on PATH"
  [[ "$("$bash_major_3" -c "printf '%s' \"\${BASH_VERSINFO[0]}\"")" == "3" ]] ||
    skip "$bash_major_3 is not bash 3.x"
  watch_dir=$(mktemp -d)
  touch "$watch_dir/seed"
  # shellcheck disable=SC2016
  run env ONCHANGE="$ONCHANGE" timeout 8s "$bash_major_3" -c '
    wd="$1"
    exec "$ONCHANGE" -W "$wd" -w "$wd" -t 2.5 -- true </dev/null 2>&1
  ' _ "$watch_dir"
  rm -rf "$watch_dir"
  [ "$status" -eq 124 ]
  [[ "$output" != *invalid*timeout* ]]
}

@test "SUR-2242: bash 3.2 open fifo fractional WaitTime without python3 (date %N) does not double-sleep" {
  [ -n "$ONCHANGE_REAL_SLEEP" ] || skip "sleep not on PATH"
  bash_major_3=
  for candidate in bash-3.2 bash32; do
    if command -v "$candidate" >/dev/null 2>&1; then
      bash_major_3=$(command -v "$candidate")
      break
    fi
  done
  [[ -n "$bash_major_3" ]] || skip "no bash-3.2 or bash32 on PATH"
  [[ "$("$bash_major_3" -c "printf '%s' \"\${BASH_VERSINFO[0]}\"")" == "3" ]] ||
    skip "$bash_major_3 is not bash 3.x"
  frac=$(date +%s.%N 2>/dev/null) || frac=
  case $frac in
    *.*) ;;
    *) skip "date lacks %N" ;;
  esac
  case ${frac##*.} in
    '' | *[!0-9]*) skip "date lacks usable %N" ;;
  esac

  mini_bin=$(mktemp -d)
  for tool_name in bash grep dirname basename cksum awk date sort find sleep env printf cat mktemp chmod mkdir ln true; do
    ln -sf "$(command -v "$tool_name")" "$mini_bin/$tool_name"
  done
  ln -sf "$bash_major_3" "$mini_bin/bash"

  watch_dir=$(mktemp -d)
  touch "$watch_dir/seed"
  fifo_dir=$(mktemp -d)
  fifo="$fifo_dir/pipe"
  mkfifo "$fifo"
  stub_bin=$(mktemp -d)
  sleep_log=$(mktemp)
  cat >"$stub_bin/sleep" <<EOF
#!/usr/bin/env bash
printf 'x\n' >>"$sleep_log"
exec "$ONCHANGE_REAL_SLEEP" "\$@"
EOF
  chmod +x "$stub_bin/sleep"
  exec 4<>"$fifo"
  run env PATH="$stub_bin:$mini_bin" timeout 6s "$ONCHANGE" -W "$watch_dir" -w "$watch_dir" -t 1.2 -- true <&4
  exec 4>&- || true
  n_sleep=$(wc -l <"$sleep_log")
  rm -rf "$watch_dir" "$stub_bin" "$fifo_dir" "$mini_bin"
  rm -f "$sleep_log"
  [ "$status" -eq 124 ]
  [ "$n_sleep" -eq 0 ]
}

@test "SUR-2242: -t 0 with pipe stdin feeding lines does not throttle with sleep" {
  [ -n "$ONCHANGE_REAL_SLEEP" ] || skip "sleep not on PATH"
  watch_dir=$(mktemp -d)
  touch "$watch_dir/seed"
  stub_bin=$(mktemp -d)
  sleep_log=$(mktemp)
  cat >"$stub_bin/sleep" <<EOF
#!/usr/bin/env bash
printf 'x\n' >>"$sleep_log"
exec "$ONCHANGE_REAL_SLEEP" "\$@"
EOF
  chmod +x "$stub_bin/sleep"
  (
    "$ONCHANGE_REAL_SLEEP" 2
    echo trig >>"$watch_dir/marker"
  ) &
  # Inner bash -c expands watch_dir and ONCHANGE; outer single quotes are intentional.
  # shellcheck disable=SC2016
  run env PATH="$stub_bin:$PATH" ONCHANGE="$ONCHANGE" timeout 5s bash -c '
    watch_dir="$1"
    while true; do printf "%s\n" idle; done | "$ONCHANGE" -W "$watch_dir" -w "$watch_dir" -t 0 -- true
  ' _ "$watch_dir"
  rm -rf "$watch_dir" "$stub_bin"
  n_sleep=$(wc -l <"$sleep_log")
  rm -f "$sleep_log"
  [ "$status" -eq 124 ]
  [ "$n_sleep" -eq 0 ]
  # Bash 3.2 rejects fractional read -t (would spam "invalid timeout specification").
  [[ "$output" != *invalid*timeout* ]]
}

@test "SUR-2242: pipe stdin feeding empty lines does not throttle with sleep (non-zero WaitTime)" {
  [ -n "$ONCHANGE_REAL_SLEEP" ] || skip "sleep not on PATH"
  watch_dir=$(mktemp -d)
  touch "$watch_dir/seed"
  stub_bin=$(mktemp -d)
  sleep_log=$(mktemp)
  cat >"$stub_bin/sleep" <<EOF
#!/usr/bin/env bash
printf 'x\n' >>"$sleep_log"
exec "$ONCHANGE_REAL_SLEEP" "\$@"
EOF
  chmod +x "$stub_bin/sleep"
  (
    "$ONCHANGE_REAL_SLEEP" 2
    echo trig >>"$watch_dir/marker"
  ) &
  # shellcheck disable=SC2016
  run env PATH="$stub_bin:$PATH" ONCHANGE="$ONCHANGE" timeout 5s bash -c '
    watch_dir="$1"
    while true; do printf "\n"; done | "$ONCHANGE" -W "$watch_dir" -w "$watch_dir" -t 2 -- true
  ' _ "$watch_dir"
  rm -rf "$watch_dir" "$stub_bin"
  n_sleep=$(wc -l <"$sleep_log")
  rm -f "$sleep_log"
  [ "$status" -eq 124 ]
  [ "$n_sleep" -eq 0 ]
}
