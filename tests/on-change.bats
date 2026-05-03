#!/usr/bin/env bats
# SUR-2179: regression coverage for bash/on-change — options, defaults,
# post-`--` argv to the watched command, and stable error paths (no wall-clock
# assertions on the polling loop itself).

setup() {
  load 'helpers.bash'
  helpers::isolate_home
  ONCHANGE="$REPO_ROOT/bash/on-change"
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
