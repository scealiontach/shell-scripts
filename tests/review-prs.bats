#!/usr/bin/env bats
# SUR-1927: review-prs must route every jq invocation through a
# commands::use-backed shim so a missing jq binary fails loudly with
# the standard "not on the PATH" error rather than silently emitting
# empty output downstream.

setup() {
  load 'helpers.bash'
  helpers::isolate_home
  TARGET="$REPO_ROOT/bash/review-prs"
  export TARGET
}

function write_review_prs_stubs() {
  local stub_bin=${1:?}
  local log_file=${2:?}

  cat >"$stub_bin/gh" <<'EOF'
#!/usr/bin/env bash
echo "$*" >>"${REVIEW_PRS_STUB_LOG:?}"
if [ "$1" = "search" ] && [ "$2" = "repos" ]; then
  owner=""
  while [ "$#" -gt 0 ]; do
    if [ "$1" = "--owner" ]; then
      owner="$2"
      shift 2
      continue
    fi
    shift
  done
  printf '[{"name":"%s-repo"}]\n' "$owner"
  exit 0
fi
if [ "$1" = "pr" ] && [ "$2" = "list" ] && [ "$3" = "--draft=false" ]; then
  printf '[{"reviewDecision":"APPROVED"}]\n'
  exit 0
fi
if [ "$1" = "pr" ] && [ "$2" = "list" ]; then
  exit 0
fi
exit 0
EOF
  chmod +x "$stub_bin/gh"

  cat >"$stub_bin/jq" <<'EOF'
#!/usr/bin/env bash
python3 -c '
import json, sys
data = json.load(sys.stdin)
expr = sys.argv[-1]
if expr == ".[].name":
    for item in data:
        print(item["name"])
elif expr == ".[].reviewDecision":
    for item in data:
        print(item["reviewDecision"])
' "$@"
EOF
  chmod +x "$stub_bin/jq"
}

@test "review-prs defines a ::jq shim" {
  run grep -E '^function ::jq\(\)' "$TARGET"
  [ "$status" -eq 0 ]
}

@test "review-prs has no bare jq invocation" {
  # Reject any non-comment line that looks like `... jq ...` not preceded by
  # `:` / `_` / a-z (so `commands::use jq`, `_jq`, and `::jq` are excluded).
  run grep -nE '^[^#]*(^|[^:_a-z])jq([[:space:]]|$)' "$TARGET"
  [ "$status" -ne 0 ]
}

@test "review-prs ::jq shim fails loudly when jq is missing from PATH (SUR-1927)" {
  run bash -c "
    export LOGFILE_DISABLE=true
    source '$REPO_ROOT/bash/includer.sh'
    @include commands
    @include log
    eval \"\$(awk '/^function ::jq\\(\\)/,/^}\$/' '$TARGET')\"
    command() {
      if [ \"\$1\" = -v ] && [ \"\$2\" = jq ]; then return 1; fi
      builtin command \"\$@\"
    }
    ::jq -r '.foo' </dev/null
  "
  [ "$status" -eq 1 ]
  [[ "$output" == *"jq is either not installed or not on the PATH"* ]]
  [[ "$output" != *"-r: command not found"* ]]
}

@test "review-prs bare invocation scans default organizations (SUR-3646)" {
  stub_bin=$(mktemp -d)
  log_file=$(mktemp)
  mkdir -p "$HOME/git/hyperledger/hyperledger-repo"
  write_review_prs_stubs "$stub_bin" "$log_file"

  run env PATH="$stub_bin:$PATH" REVIEW_PRS_STUB_LOG="$log_file" LOGFILE_DISABLE=true \
    bash "$TARGET"
  [ "$status" -eq 0 ]
  [[ "$(cat "$log_file")" == *"search repos --owner 391agency --archived=false --json name"* ]]
  [[ "$(cat "$log_file")" == *"search repos --owner btpworks --archived=false --json name"* ]]
  [[ "$(cat "$log_file")" == *"search repos --owner blockchaintp --archived=false --json name"* ]]
  [[ "$(cat "$log_file")" == *"search repos --owner catenasys --archived=false --json name"* ]]
  [[ "$(cat "$log_file")" == *"search repos --owner hyperledger --archived=false --json name"* ]]
  [[ "$(cat "$log_file")" == *"pr list --draft=false --repo 391agency/391agency-repo --json reviewDecision"* ]]
  [[ "$(cat "$log_file")" == *"pr list --draft=false --repo hyperledger/hyperledger-repo --json reviewDecision"* ]]

  rm -rf "$stub_bin"
  rm -f "$log_file"
}

@test "review-prs honors explicit -o and -i arguments (SUR-3646)" {
  stub_bin=$(mktemp -d)
  log_file=$(mktemp)
  mkdir -p "$HOME/git/focused/focused-repo"
  write_review_prs_stubs "$stub_bin" "$log_file"

  run env PATH="$stub_bin:$PATH" REVIEW_PRS_STUB_LOG="$log_file" LOGFILE_DISABLE=true \
    bash "$TARGET" -o direct -i focused
  [ "$status" -eq 0 ]
  [[ "$(cat "$log_file")" == *"search repos --owner direct --archived=false --json name"* ]]
  [[ "$(cat "$log_file")" == *"search repos --owner focused --archived=false --json name"* ]]
  [[ "$(cat "$log_file")" != *"search repos --owner 391agency --archived=false --json name"* ]]
  [[ "$(cat "$log_file")" != *"search repos --owner hyperledger --archived=false --json name"* ]]

  rm -rf "$stub_bin"
  rm -f "$log_file"
}
