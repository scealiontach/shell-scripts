#!/usr/bin/env bats
# SUR-1872: replace-validator must include `commands` directly, route
# `jq` through `commands::use jq`, and accept the node↔pod maps via
# nameref so callers own them as locals rather than script-scope
# globals.

setup() {
  load 'helpers.bash'
  helpers::isolate_home
  TARGET="$REPO_ROOT/bash/replace-validator"
  export TARGET
}

@test "mapPods populates both maps via nameref using stubbed k8s::ctl" {
  TEST_SCRIPT=$(mktemp)
  cat >"$TEST_SCRIPT" <<EOF
set -e
source '$REPO_ROOT/bash/includer.sh'
@include commands
@include log

# Stub k8s::ctl with canned responses for the three queries mapPods drives.
k8s::ctl() {
  case "\$*" in
    'get pods -l app=foo -o name')
      echo pod/example-pod-1
      echo pod/example-pod-2
      ;;
    'get pod/example-pod-1 -o json')
      echo '{"spec":{"nodeName":"node-A"}}'
      ;;
    'get pod/example-pod-2 -o json')
      echo '{"spec":{"nodeName":"node-B"}}'
      ;;
    *)
      echo "unexpected k8s::ctl args: \$*" >&2
      return 1
      ;;
  esac
}

# Pull in only the three relevant function definitions from
# replace-validator, bypassing its option parsing and main invocation.
eval "\$(awk '/^function getPodsForLabel\\(/,/^}\$/' '$TARGET')"
eval "\$(awk '/^function getNodeForPod\\(/,/^}\$/' '$TARGET')"
eval "\$(awk '/^function mapPods\\(/,/^}\$/' '$TARGET')"

declare -A node2pod=()
declare -A pod2node=()
mapPods app=foo node2pod pod2node

[ "\${node2pod[node-A]}" = example-pod-1 ]
[ "\${node2pod[node-B]}" = example-pod-2 ]
[ "\${pod2node[example-pod-1]}" = node-A ]
[ "\${pod2node[example-pod-2]}" = node-B ]
EOF
  run bash "$TEST_SCRIPT"
  rm -f "$TEST_SCRIPT"
  [ "$status" -eq 0 ]
}

@test "replace-validator declares @include commands" {
  run grep -E '^@include[[:space:]]+commands\b' "$TARGET"
  [ "$status" -eq 0 ]
}

@test "replace-validator routes jq through commands::use jq" {
  # No bare `jq` invocation should remain on a non-comment line.
  run grep -E '^[^#]*[^a-zA-Z_:]jq[[:space:]]+-' "$TARGET"
  [ "$status" -ne 0 ]
}

@test "no script-scope declare -A node2pod/pod2node remains in replace-validator" {
  run grep -E '^declare[[:space:]]+-A[[:space:]]+(node2pod|pod2node)\b' "$TARGET"
  [ "$status" -ne 0 ]
}
