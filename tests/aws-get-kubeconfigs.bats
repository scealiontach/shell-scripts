#!/usr/bin/env bats
# SUR-2238: aws-get-kubeconfigs eksctl/jq wiring and error::exit paths.

setup() {
  load 'helpers.bash'
  helpers::isolate_home
  export LOGFILE_DISABLE=true LOG_DISABLE_INFO=true
  SCRIPT="$REPO_ROOT/bash/aws-get-kubeconfigs"
  STUB_BIN=$(mktemp -d)
  EKSCTL_LOG=$(mktemp)

  cat >"$STUB_BIN/eksctl" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$EKSCTL_LOG"
if [[ "\$*" == *"get clusters"* ]]; then
  printf '%s' '[{"Name":"cluster-a","Region":"us-west-2"},{"Name":"cluster-b","Region":"eu-central-1"}]'
elif [[ "\$1" == "utils" && "\$2" == "write-kubeconfig" ]]; then
  exit "\${EKSCTL_WRITE_RC:-0}"
fi
STUB
  chmod +x "$STUB_BIN/eksctl"

  cat >"$STUB_BIN/jq" <<'STUB'
#!/usr/bin/env bash
cat >/dev/null
printf '%s\t%s\n' cluster-a us-west-2
printf '%s\t%s\n' cluster-b eu-central-1
STUB
  chmod +x "$STUB_BIN/jq"

  export PATH="$STUB_BIN:$PATH"
  unset _eksctl _jq
}

teardown() {
  rm -rf "$STUB_BIN"
  rm -f "$EKSCTL_LOG"
}

@test "get clusters and write-kubeconfig per cluster/region" {
  unset EKSCTL_WRITE_RC
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -Fq 'get clusters' "$EKSCTL_LOG"
  grep -Fq 'utils write-kubeconfig' "$EKSCTL_LOG"
  grep -Fq -- '--cluster cluster-a' "$EKSCTL_LOG"
  grep -Fq -- '--region us-west-2' "$EKSCTL_LOG"
  grep -Fq -- '--cluster cluster-b' "$EKSCTL_LOG"
  grep -Fq -- '--region eu-central-1' "$EKSCTL_LOG"
}

@test "forwards AWS profile to eksctl when -p is set" {
  unset EKSCTL_WRITE_RC
  run "$SCRIPT" -p 'ci-profile'
  [ "$status" -eq 0 ]
  grep -Fq 'get clusters --profile ci-profile' "$EKSCTL_LOG"
  grep -Fq 'utils write-kubeconfig --profile ci-profile' "$EKSCTL_LOG"
}

@test "error::exit when write-kubeconfig fails" {
  export EKSCTL_WRITE_RC=1
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Failed to update kubeconfig"* ]]
}
