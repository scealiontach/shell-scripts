#!/usr/bin/env bats
# SUR-2177: k8s-support-collector options and selected functions with
# stubbed k8s:: / exec:: / dirs. Pairs with SUR-2171 (pod_sname local).

setup() {
  load 'helpers.bash'
  helpers::isolate_home
  COLLECTOR="$REPO_ROOT/bash/k8s-support-collector"
  export LOGFILE_DISABLE=true LOG_DISABLE_DEBUG=true LOG_DISABLE_INFO=true
}

@test "K8S_SUPPORT_COLLECTOR_SOURCE_ONLY exits 0 when executed (no main body)" {
  out=$(mktemp -d)
  run env K8S_SUPPORT_COLLECTOR_SOURCE_ONLY=true \
    bash "$COLLECTOR" -n isolated-ns -o "$out"
  rm -rf "$out"
  [ "$status" -eq 0 ]
  [[ "$output" != *"Saving topology"* ]]
  [[ "$output" != *"Collecting information from all namespaces"* ]]
}

@test "sourced collector exports NAMESPACE and OUT_DIR from flags" {
  out=$(mktemp -d)
  run bash -c "
    export K8S_SUPPORT_COLLECTOR_SOURCE_ONLY=true
    source '$COLLECTOR' -n my-namespace -o '$out'
    printf 'NAMESPACE=%s OUT_DIR=%s' \"\${NAMESPACE}\" \"\${OUT_DIR}\"
  "
  rm -rf "$out"
  [ "$status" -eq 0 ]
  [[ "$output" == *"NAMESPACE=my-namespace OUT_DIR=$out"* ]]
}

@test "logs keeps pod_sname function-local (SUR-2171)" {
  out=$(mktemp -d)
  run bash -c "
    export K8S_SUPPORT_COLLECTOR_SOURCE_ONLY=true
    source '$COLLECTOR' -n testns -o '$out'
    k8s::get_pod_names() { echo 'pod/waffle-validator-0'; }
    k8s::get_containers_for_pod() { echo validator; }
    k8s::log() { :; }
    k8s::cp() { :; }
    exec::hide() { \"\$@\"; }
    pod_sname='marker_before'
    logs testns
    printf '%s' \"\${pod_sname}\"
  "
  rm -rf "$out"
  [ "$status" -eq 0 ]
  [[ "$(printf '%s\n' "$output" | tail -1)" == "marker_before" ]]
}

@test "create_package tarball name uses cluster and namespace" {
  run bash -c "
    cd '${BATS_TEST_TMPDIR}' || exit 1
    export K8S_SUPPORT_COLLECTOR_SOURCE_ONLY=true
    out=\$(mktemp -d)
    echo x >\"\$out/collect-me.txt\"
    source '$COLLECTOR' -n prod -o \"\$out\"
    k8s::current_cluster() { echo 'my/prod-cluster'; }
    date() { printf '%s\n' 'TSFIX'; }
    create_package
    ls -1 ./*.tar.gz
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"my_prod-cluster.prod-TSFIX.tar.gz"* ]]
}

@test "create_package uses ALL segment when ALL_NAMESPACES is true" {
  run bash -c "
    cd '${BATS_TEST_TMPDIR}' || exit 1
    export K8S_SUPPORT_COLLECTOR_SOURCE_ONLY=true
    out=\$(mktemp -d)
    echo y >\"\$out/f.txt\"
    source '$COLLECTOR' -A -n ignored -o \"\$out\"
    k8s::current_cluster() { echo 'ctx/cluster'; }
    date() { printf '%s\n' 'TS2'; }
    create_package
    ls -1 ./*.tar.gz
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"ctx_cluster.ALL-TS2.tar.gz"* ]]
}
