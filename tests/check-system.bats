#!/usr/bin/env bats
# SUR-2237: check-system local vs SSH paths with PATH stubs.

setup() {
  load 'helpers.bash'
  helpers::isolate_home
  export LOGFILE_DISABLE=true LOG_LEVEL=2
  SCRIPT="$REPO_ROOT/bash/check-system"
  STUB_BIN=$(mktemp -d)
  TOOLS_STUB="$STUB_BIN/tools"
  SSH_STUB="$STUB_BIN/sshonly"
  mkdir -p "$TOOLS_STUB" "$SSH_STUB"
  SSH_LOG=$(mktemp)

  cat >"$TOOLS_STUB/dmidecode" <<'STUB'
#!/usr/bin/env bash
case "$*" in
  *bios-vendor*) echo "StubVendor" ;;
  *bios-version*) echo "9.8.7" ;;
  *bios-release-date*) echo "01/02/2003" ;;
  *) echo "unknown"; exit 1 ;;
esac
STUB
  chmod +x "$TOOLS_STUB/dmidecode"

  cat >"$TOOLS_STUB/lsmod" <<'STUB'
#!/usr/bin/env bash
echo "Module                  Size  Used by"
echo "isgx                  40960  0"
STUB
  chmod +x "$TOOLS_STUB/lsmod"

  cat >"$TOOLS_STUB/modinfo" <<'STUB'
#!/usr/bin/env bash
# Real modinfo --field=srcversion prints the value only.
echo "ABC123DEV"
STUB
  chmod +x "$TOOLS_STUB/modinfo"

  cat >"$SSH_STUB/ssh" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$SSH_LOG"
remote="\${*: -1}"
case "\$remote" in
  *bios-vendor*) echo "RemoteVendor" ;;
  *bios-version*) echo "1.0.0" ;;
  *bios-release-date*) echo "03/04/2005" ;;
  *lsmod*)
    echo "Module                  Size  Used by"
    echo "isgx                  12345  0"
    ;;
  *modinfo*) echo "srcversion      REMOTE999" ;;
  *) echo "bad-remote" >&2; exit 1 ;;
esac
STUB
  chmod +x "$SSH_STUB/ssh"

  export PATH="$SSH_STUB:$TOOLS_STUB:$PATH"
  unset _ssh _dmidecode _lsmod _modinfo
}

teardown() {
  rm -rf "$STUB_BIN"
  rm -f "$SSH_LOG"
}

# PATH without /usr/bin still needs core utilities used while sourcing libraries.
populate_minimal_host_tools_bin() {
  local mini_bin=${1:?}
  mkdir -p "$mini_bin"
  local tool_name
  for tool_name in bash grep dirname basename cksum awk date; do
    ln -sf "$(command -v "$tool_name")" "$mini_bin/$tool_name"
  done
}

@test "local run logs bios and driver details for localhost" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"host=localhost"* ]]
  [[ "$output" == *"bios vendor=StubVendor"* ]]
  [[ "$output" == *"version=9.8.7"* ]]
  [[ "$output" == *"driver=ABC123DEV"* ]]
}

@test "local run finds dmidecode via fallback dir when not on PATH" {
  local fake_sbin="$STUB_BIN/fallback_dmidecode"
  local mini_bin="$STUB_BIN/mini_bin"
  mkdir -p "$fake_sbin"
  populate_minimal_host_tools_bin "$mini_bin"
  cp "$TOOLS_STUB/dmidecode" "$fake_sbin/dmidecode"
  chmod +x "$fake_sbin/dmidecode"
  rm -f "$TOOLS_STUB/dmidecode"

  # PATH must omit real /usr/bin/dmidecode so resolution exercises fallback dirs.
  run env CHECK_SYSTEM_SBIN_FALLBACK_DIRS="$fake_sbin" \
    PATH="$SSH_STUB:$TOOLS_STUB:$mini_bin" \
    bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"bios vendor=StubVendor"* ]]
}

@test "local run finds lsmod via fallback dir when not on PATH" {
  local fake_sbin="$STUB_BIN/fallback_lsmod"
  local mini_bin="$STUB_BIN/mini_bin"
  mkdir -p "$fake_sbin"
  populate_minimal_host_tools_bin "$mini_bin"
  cp "$TOOLS_STUB/lsmod" "$fake_sbin/lsmod"
  chmod +x "$fake_sbin/lsmod"
  rm -f "$TOOLS_STUB/lsmod"

  run env CHECK_SYSTEM_SBIN_FALLBACK_DIRS="$fake_sbin" \
    PATH="$SSH_STUB:$TOOLS_STUB:$mini_bin" \
    bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"driver=ABC123DEV"* ]]
}

@test "local run without isgx reports driver as (none)" {
  cat >"$TOOLS_STUB/lsmod" <<'STUB'
#!/usr/bin/env bash
echo "Module                  Size  Used by"
echo "nf_conntrack          99999  0"
STUB
  chmod +x "$TOOLS_STUB/lsmod"

  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No ISGX driver loaded on localhost"* ]]
  [[ "$output" == *"driver=(none)"* ]]
}

@test "SSH mode invokes ssh per host and prints host lines" {
  run "$SCRIPT" -s 'edge-one' 'edge-two'
  [ "$status" -eq 0 ]
  [[ "$output" == *"host=edge-one"* ]]
  [[ "$output" == *"host=edge-two"* ]]
  [[ "$output" == *"bios vendor=RemoteVendor"* ]]
  grep -Fq 'edge-one' "$SSH_LOG"
  grep -Fq 'edge-two' "$SSH_LOG"
  # Remote payload must use bare tool names, not local PATH stubs under TOOLS_STUB.
  run grep -Fq "$TOOLS_STUB" "$SSH_LOG"
  [ "$status" -ne 0 ]
  grep -Fq 'dmidecode -s bios-vendor' "$SSH_LOG"
  grep -Fq 'lsmod' "$SSH_LOG"
  grep -Fq 'modinfo isgx' "$SSH_LOG"
}
