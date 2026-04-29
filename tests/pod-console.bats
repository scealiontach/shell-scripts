#!/usr/bin/env bats
# SUR-1869: pod-console must build the tmux send-keys payload via
# printf %q so that user-quoted positional args round-trip through the
# remote shell instead of being collapsed by IFS-joined "$*".

setup() {
  load 'helpers.bash'
  helpers::isolate_home

  STUB_BIN=$(mktemp -d)
  TMUX_ARGV_LOG=$(mktemp)
  KUBECTL_ARGV_LOG=$(mktemp)

  # tmux stub: record each invocation as a single line, NUL-separating
  # the argv elements so the test can split them deterministically even
  # when individual args contain spaces or quotes.
  cat >"$STUB_BIN/tmux" <<'STUB'
#!/usr/bin/env bash
{
  for a in "$@"; do
    printf '%s\0' "$a"
  done
  printf '\n'
} >>"${TMUX_ARGV_LOG:-/dev/null}"
case "$1" in
  has-session) exit 1 ;;
esac
exit 0
STUB
  chmod +x "$STUB_BIN/tmux"

  # kubectl stub: log argv and emit a single pod when '-o name' is asked
  # for. One pod is enough; the bug surfaces on the first send-keys.
  cat >"$STUB_BIN/kubectl" <<'STUB'
#!/usr/bin/env bash
echo "$@" >>"${KUBECTL_ARGV_LOG:-/dev/null}"
case "$*" in
  *"-o name"*) echo "pod/example-pod-1" ;;
esac
STUB
  chmod +x "$STUB_BIN/kubectl"

  PATH="$STUB_BIN:$PATH"
  unset _tmux _kubectl
  export STUB_BIN TMUX_ARGV_LOG KUBECTL_ARGV_LOG PATH
}

teardown() {
  rm -rf "$STUB_BIN"
  rm -f "$TMUX_ARGV_LOG" "$KUBECTL_ARGV_LOG"
}

@test "send-keys payload preserves quoting on positional arguments" {
  run "$REPO_ROOT/bash/pod-console" -l app=foo -c exec -- \
    bash -c 'echo "two words"'
  [ "$status" -eq 0 ]

  # Each tmux invocation is one \n-terminated line in the argv log; the
  # args within a line are NUL-separated. Pick the line that begins with
  # send-keys and split on NUL to recover individual args.
  send_line=$(grep -a '^send-keys' "$TMUX_ARGV_LOG" | tr '\0' '\n')
  [ -n "$send_line" ]

  # tmux send-keys layout: send-keys -t SESSION PAYLOAD C-m. The payload
  # is the 4th NUL-separated field (1-indexed).
  payload=$(awk 'NR==4 {print; exit}' <<<"$send_line")
  [ -n "$payload" ]

  # Re-evaluate the payload as the remote shell would, then assert the
  # last positional arg is the original quoted string intact.
  eval "set -- $payload"
  [ "${!#}" = 'echo "two words"' ]
}

@test "no \$* expansion remains in pod-console (excluding comments)" {
  # Strip comment-only and trailing-comment content before matching, so
  # any commentary that mentions the historical bug does not trip the
  # assertion.
  run bash -c "grep -nE '\\\$\\*' '$REPO_ROOT/bash/pod-console' | grep -vE '^[0-9]+:[[:space:]]*#' | grep -E '\\\$\\*'"
  [ "$status" -ne 0 ]
}
